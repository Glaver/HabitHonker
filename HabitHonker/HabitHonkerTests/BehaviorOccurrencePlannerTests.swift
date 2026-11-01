import Foundation
import XCTest
@testable import HabitHonker

final class BehaviorOccurrencePlannerTests: XCTestCase {
    func testDeterministicRepeatingIdentityAndFrozenFacts() throws {
        let a = try D.planned(D.plan())
        XCTAssertEqual(a.logicalOccurrenceID, "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2027-01-14")
        XCTAssertEqual(a, try D.planned(D.plan()))
        XCTAssertEqual(a.targetID, D.target)
        XCTAssertEqual(a.taskType, .repeating)
        XCTAssertEqual(a.snapshot, D.snapshot())
        XCTAssertNil(a.scheduledAt)
        XCTAssertNil(a.dueAt)
    }

    func testEachWeekdayAndMultiDayMasks() throws {
        for offset in 0..<7 { // January 10 is Sunday.
            let date = D.date("2027-01-\(10 + offset)T20:00:00Z")
            for bit in 0..<7 {
                let result = D.plan(at: date, snapshot: D.snapshot(mask: 1 << bit))
                if bit == offset { _ = try D.planned(result) }
                else { XCTAssertEqual(result, .noOccurrence(.weekdayNotSelected)) }
            }
            _ = try D.planned(D.plan(at: date, snapshot: D.snapshot(mask: 127)))
        }
        XCTAssertEqual(D.plan(snapshot: D.snapshot(mask: 0)), .noOccurrence(.weekdayNotSelected))
        _ = try D.planned(D.plan(snapshot: D.snapshot(mask: 2 | 16)))
    }

    func testHistoricalOwnershipAndExactTransitionAreOrderIndependent() throws {
        let t = D.date("2027-01-14T08:00:00Z")
        let old = D.row("old", to: t)
        var changed = D.snapshot()
        changed.priority = .notUrgentAndNotImportant
        changed.iconName = "new"
        let new = D.row("new", from: t, snapshot: changed)
        for rows in [[old, new], [new, old]] {
            let before = try D.planned(D.plan(at: D.date("2027-01-13T20:00:00Z"), rows: rows))
            XCTAssertEqual(before.scheduleRevisionID, "old")
            XCTAssertEqual(before.snapshot, D.snapshot())
            let at = try D.planned(D.plan(at: t, rows: rows))
            XCTAssertEqual(at.scheduleRevisionID, "new")
            XCTAssertEqual(at.snapshot, changed)
        }
        XCTAssertEqual(D.plan(at: t, rows: [old]), .noOccurrence(.noActiveRevision))
        XCTAssertEqual(try D.planned(D.plan(at: t, rows: [new])).scheduleRevisionID, "new")
    }

    func testOneTimeBeforeAtAfterDueKeepsIdentityAndDueDay() throws {
        let due = D.date("2027-01-14T20:00:00Z")
        for action in [D.date("2027-01-13T20:00:00Z"), due, D.date("2027-01-15T20:00:00Z")] {
            let occurrence = try D.planned(D.plan(at: action, snapshot: D.once(due)))
            XCTAssertEqual(occurrence.logicalOccurrenceID, "occ:v1:123e4567-e89b-12d3-a456-426614174000:once")
            XCTAssertEqual(occurrence.localDay.canonicalKey, "2027-01-14")
            XCTAssertEqual(occurrence.dueAt, due)
            XCTAssertNil(occurrence.scheduledAt)
        }
    }

    func testEnrollmentBeforeAtAfterAndPartialUntimedDay() throws {
        let p = D.policy(start: D.action)
        let rows = [D.row(from: D.action)]
        XCTAssertEqual(D.plan(at: D.date("2027-01-14T19:00:00Z"), rows: rows, policy: p), .noOccurrence(.beforeEnrollment))
        _ = try D.planned(D.plan(rows: rows, policy: p))
        _ = try D.planned(D.plan(at: D.date("2027-01-14T21:00:00Z"), rows: rows, policy: p))
        XCTAssertEqual(D.plan(snapshot: D.once(D.start.addingTimeInterval(-1))), .noOccurrence(.candidateBeforeEnrollment))
        XCTAssertEqual(D.plan(rows: [D.row(from: D.action, snapshot: D.snapshot(hour: 7))], policy: p),
                       .noOccurrence(.candidateBeforeEnrollment))
    }

    func testUTCDateCrossingUsesProfileDay() throws {
        let a = try D.planned(D.plan(at: D.date("2027-01-15T01:00:00Z")))
        XCTAssertEqual(a.localDay.canonicalKey, "2027-01-14")
        XCTAssertEqual(a.logicalOccurrenceID, try D.planned(D.plan()).logicalOccurrenceID)
    }

    func testSpringForwardUsesNextValidTime() throws {
        let a = try D.planned(D.plan(at: D.date("2027-03-14T19:00:00Z"), snapshot: D.snapshot(hour: 2, minute: 30)))
        XCTAssertEqual(a.scheduledAt, D.date("2027-03-14T10:00:00Z"))
        XCTAssertEqual(a.localDay.duration, 23 * 3600)
        XCTAssertEqual(a.localDay.canonicalKey, "2027-03-14")
    }

    func testFallBackUsesFirstRepeatedTime() throws {
        let snapshot = D.snapshot(hour: 1, minute: 30)
        let a = try D.planned(D.plan(at: D.date("2027-11-07T08:45:00Z"), snapshot: snapshot))
        let b = try D.planned(D.plan(at: D.date("2027-11-07T09:45:00Z"), snapshot: snapshot))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.scheduledAt, D.date("2027-11-07T08:30:00Z"))
        XCTAssertEqual(a.localDay.duration, 25 * 3600)
    }

    func testMidnightAndNearMidnightAndNotificationsOff() throws {
        for (hour, minute, expected) in [(0, 0, "2027-01-14T08:00:00Z"), (23, 59, "2027-01-15T07:59:00Z")] {
            XCTAssertEqual(try D.planned(D.plan(snapshot: D.snapshot(hour: hour, minute: minute))).scheduledAt, D.date(expected))
        }
        XCTAssertNil(try D.planned(D.plan()).scheduledAt)
    }

    func testTimedCandidateMustBeInsideHalfOpenRevision() throws {
        let due = D.action
        XCTAssertEqual(D.plan(rows: [D.row(to: due, snapshot: D.once(due))], atOverride: due.addingTimeInterval(-3600)),
                       .noOccurrence(.candidateOutsideRevision))
        _ = try D.planned(D.plan(rows: [D.row(from: due, snapshot: D.once(due))]))
        XCTAssertEqual(D.plan(rows: [D.row(from: D.action, snapshot: D.snapshot(hour: 7))]), .noOccurrence(.candidateOutsideRevision))
        XCTAssertEqual(D.plan(rows: [D.row(to: D.action.addingTimeInterval(3600), snapshot: D.snapshot(hour: 23))]),
                       .noOccurrence(.candidateOutsideRevision))
    }

    func testHealthyGapAndExactRestoreBoundaryAreOrderIndependent() throws {
        let restored = D.action.addingTimeInterval(3600)
        let old = D.row("old", to: D.action)
        let new = D.row("new", from: restored)
        for rows in [[old, new], [new, old]] {
            XCTAssertEqual(D.plan(rows: rows), .noOccurrence(.noActiveRevision))
            XCTAssertEqual(D.plan(at: D.action.addingTimeInterval(1800), rows: rows), .noOccurrence(.noActiveRevision))
            XCTAssertEqual(try D.planned(D.plan(at: restored, rows: rows)).scheduleRevisionID, "new")
            XCTAssertEqual(try D.planned(D.plan(at: D.action.addingTimeInterval(-1), rows: rows)).scheduleRevisionID, "old")
        }
    }

    func testAfterFinalClosedRevisionIsInactive() {
        let rows = [D.row(to: D.action)]
        XCTAssertEqual(D.plan(rows: rows), .noOccurrence(.noActiveRevision))
        XCTAssertEqual(D.plan(at: D.action.addingTimeInterval(3600), rows: rows), .noOccurrence(.noActiveRevision))
    }

    func testEmptyAndPreFirstHistoryRemainInsufficient() {
        XCTAssertEqual(D.plan(rows: []), .deferred(.missingRevision))
        for end in [nil, Optional(D.action.addingTimeInterval(7200))] {
            XCTAssertEqual(D.plan(rows: [D.row(from: D.action.addingTimeInterval(3600), to: end)]),
                           .deferred(.missingRevision))
        }
    }

    func testUnsafeHistoryCannotBeClassifiedAsInactive() {
        let closed = D.row("closed", to: D.action)
        let bad = BehaviorScheduleRevisionFacts(logicalRevisionID: "bad", effectiveFrom: D.action,
            effectiveTo: D.action, snapshot: nil)
        XCTAssertEqual(D.plan(rows: [closed, bad]), .deferred(.undecodableSnapshot))
        XCTAssertEqual(D.plan(rows: [closed, closed]), .deferred(.duplicateRevisionIdentity))
        XCTAssertEqual(D.plan(rows: [closed, D.row("overlap", to: D.action)]), .deferred(.overlappingRevisions))
        XCTAssertEqual(D.plan(rows: [closed, D.row("backwards", from: D.action, to: D.start)]), .deferred(.invalidInterval))
        var malformed = D.snapshot(); malformed.selectedWeekdaysMask = 128
        XCTAssertEqual(D.plan(rows: [D.row(to: D.action, snapshot: malformed)]), .deferred(.invalidSnapshot))
        XCTAssertEqual(D.plan(rows: [D.row(from: D.start.addingTimeInterval(-1), to: D.action)]), .deferred(.historyPredatesEnrollment))
    }

    func testOverlapsAndPhysicalDuplicatesNeverChooseARow() {
        XCTAssertEqual(D.plan(rows: [D.row(), D.row("other")]), .deferred(.overlappingRevisions))
        XCTAssertEqual(D.plan(rows: [D.row(), D.row()]), .deferred(.duplicateRevisionIdentity))
        let rows = [D.row("a"), D.row("b", from: D.action)]
        XCTAssertEqual(D.plan(rows: rows), D.plan(rows: rows.reversed()))
    }

    func testInvalidAndEmptyIntervals() throws {
        XCTAssertEqual(D.plan(rows: [D.row(from: D.action, to: D.start)]), .deferred(.invalidInterval))
        let empty = D.row("empty", from: D.action, to: D.action)
        _ = try D.planned(D.plan(rows: [empty, D.row()]))
        XCTAssertEqual(D.plan(rows: [empty]), .deferred(.missingRevision))
    }

    func testUndecodableAndMalformedHistory() {
        let bad = BehaviorScheduleRevisionFacts(logicalRevisionID: "bad", effectiveFrom: D.start, effectiveTo: nil, snapshot: nil)
        XCTAssertEqual(D.plan(rows: [bad]), .deferred(.undecodableSnapshot))
        var variants: [BehaviorScheduleSnapshot] = []
        var s = D.snapshot(); s.selectedWeekdaysMask = 128; variants.append(s)
        s = D.snapshot(); s.scheduledHour = 7; variants.append(s)
        s = D.snapshot(hour: 24); variants.append(s)
        s = D.snapshot(hour: 1, minute: 60); variants.append(s)
        s = D.snapshot(); s.dueAt = D.action; variants.append(s)
        s = D.snapshot(); s.schedulingTimeZoneIdentifier = "Asia/Tokyo"; variants.append(s)
        s = D.snapshot(); s.schedulingCalendarIdentifier = "buddhist"; variants.append(s)
        s = D.once(D.action); s.dueAt = nil; variants.append(s)
        s = D.once(D.action); s.selectedWeekdaysMask = 1; variants.append(s)
        s = D.snapshot(); s.targetID = BehaviorTargetID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!); variants.append(s)
        for snapshot in variants { XCTAssertEqual(D.plan(snapshot: snapshot), .deferred(.invalidSnapshot)) }
        XCTAssertEqual(D.plan(rows: [D.row(from: D.start.addingTimeInterval(-1))]), .deferred(.historyPredatesEnrollment))
    }

    func testNonfiniteInputAndBoundariesAreRejected() {
        XCTAssertEqual(D.plan(at: Date(timeIntervalSince1970: .infinity)), .deferred(.invalidInstant))
        XCTAssertEqual(D.plan(rows: [D.row(to: Date(timeIntervalSince1970: .infinity))]), .deferred(.invalidInterval))
    }

    func testPlannerSourceArchitecture() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("HabitHonker")
        for file in ["Core/Services/BehaviorOccurrencePlanner.swift", "Core/Protocols/BehaviorOccurrencePlanning.swift", "Core/Domain/BehaviorOccurrencePlan.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            XCTAssertEqual(source.components(separatedBy: .newlines).filter { $0.hasPrefix("import ") }, ["import Foundation"])
            for token in ["SwiftData", "SwiftUI", "CloudKit", "Combine", "Date()", "Calendar.current", "TimeZone.current", "Locale.current", "UUID()", "Hasher", "hashValue", ".save(", "Task {", "@Model", "GamificationProfileSD", "GamificationLedgerEntrySD", "HabitRecord"] {
                XCTAssertFalse(source.contains(token), "\(file): \(token)")
            }
        }
    }
}

/// Pure fixtures: no persistence or current Habit definition.
enum D {
    static let target = BehaviorTargetID(UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!)
    static let start = date("2027-01-01T08:00:00Z")
    static let action = date("2027-01-14T20:00:00Z")
    static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    static func policy(start: Date = D.start) -> BehaviorSchedulingPolicy {
        guard case let .enrolled(p) = BehaviorScheduleEnrollment.resolve(profiles: [BehaviorScheduleProfileFacts(
            trackingStartedAt: start, schedulingTimeZoneIdentifier: "America/Los_Angeles", schedulingCalendarIdentifier: "gregorian")], revisionHistoryExists: { true }) else { fatalError("fixture") }
        return p
    }
    static func snapshot(mask: Int = 127, hour: Int? = nil, minute: Int = 0) -> BehaviorScheduleSnapshot {
        BehaviorScheduleSnapshot(targetID: target, taskType: .repeating, selectedWeekdaysMask: mask,
            scheduledHour: hour, scheduledMinute: hour == nil ? nil : minute, dueAt: nil,
            schedulingTimeZoneIdentifier: "America/Los_Angeles", schedulingCalendarIdentifier: "gregorian",
            priority: .importantAndUrgent, iconName: "atom", notificationEnabled: hour != nil)
    }
    static func once(_ due: Date) -> BehaviorScheduleSnapshot {
        var s = snapshot(mask: 0); s.taskType = .oneTime; s.dueAt = due; return s
    }
    static func row(_ id: String = "baseline", from: Date = D.start, to: Date? = nil,
                    snapshot: BehaviorScheduleSnapshot = D.snapshot()) -> BehaviorScheduleRevisionFacts {
        BehaviorScheduleRevisionFacts(logicalRevisionID: id, effectiveFrom: from, effectiveTo: to, snapshot: snapshot)
    }
    static func plan(at: Date = D.action, snapshot: BehaviorScheduleSnapshot = D.snapshot(),
                     rows: [BehaviorScheduleRevisionFacts]? = nil, policy: BehaviorSchedulingPolicy = D.policy(),
                     atOverride: Date? = nil) -> BehaviorOccurrencePlan {
        let planner: any BehaviorOccurrencePlanning = BehaviorOccurrencePlanner()
        return planner.plan(BehaviorOccurrencePlanningInput(targetID: target, policy: policy,
            revisions: rows ?? [row(snapshot: snapshot)], actionAt: atOverride ?? at))
    }
    static func planned(_ result: BehaviorOccurrencePlan, file: StaticString = #filePath, line: UInt = #line) throws -> BehaviorPlannedOccurrence {
        guard case let .planned(value) = result else {
            XCTFail("Expected planned, got \(result)", file: file, line: line)
            throw NSError(domain: "PlannerTests", code: 1)
        }
        return value
    }
}
