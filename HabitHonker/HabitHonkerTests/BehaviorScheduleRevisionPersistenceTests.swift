import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4B B32-B46, B63, B82, B83: pre-enrollment behavior and the healthy enrolled path, through
/// the production repository actor on real V2 stores.
@MainActor
final class BehaviorScheduleRevisionPersistenceTests: XCTestCase {

    // MARK: B32-B37 - before enrollment: Habit mutations work, no revision is written

    func testB32CreateBeforeEnrollmentWritesNoRevision() async throws {
        let store = try TxStore.memory()
        let ids = Sched.UUIDSequence()
        let result = try await Sched.repository(store, ids: ids)
            .createHabit(id: Sched.targetUUID, metadata: Sched.metadata(), effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(result.scheduleHistory, .notEnrolled)
        XCTAssertEqual(result.habit.title, "Gym")
        XCTAssertEqual(try Sched.habitCount(store), 1)
        try assertNoScheduleHistory(store, ids: ids)
    }

    func testB33TitleUpdateBeforeEnrollmentWritesNoRevision() async throws {
        let store = try TxStore.memory(); try Sched.seedHabit(store)
        let ids = Sched.UUIDSequence()
        let result = try await Sched.repository(store, ids: ids)
            .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.title = "Gym (evening)" },
                            effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(result.scheduleHistory, .notEnrolled)
        XCTAssertEqual(try Sched.habitFacts(store).title, "Gym (evening)")
        try assertNoScheduleHistory(store, ids: ids)
    }

    func testB34PriorityUpdateBeforeEnrollmentWritesNoRevision() async throws {
        let store = try TxStore.memory(); try Sched.seedHabit(store)
        let ids = Sched.UUIDSequence()
        let result = try await Sched.repository(store, ids: ids)
            .updatePriority(id: Sched.targetUUID, priority: .notUrgentAndNotImportant, effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(result.scheduleHistory, .notEnrolled)
        XCTAssertEqual(result.habit.priority, .notUrgentAndNotImportant)
        XCTAssertEqual(try Sched.habitFacts(store).priorityRaw, PriorityEisenhower.notUrgentAndNotImportant.rawValue)
        try assertNoScheduleHistory(store, ids: ids)
    }

    func testB35ScheduleEditBeforeEnrollmentWritesNoRevision() async throws {
        let store = try TxStore.memory(); try Sched.seedHabit(store)
        let ids = Sched.UUIDSequence()
        let newTime = Sched.at(day: 0, hour: 18, minute: 15)
        let result = try await Sched.repository(store, ids: ids)
            .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.repeating = [.tuesday, .thursday]
                $0.dueDate = newTime
                $0.icon = "bed"
                $0.isNotificationActivated = false
            }, effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(result.scheduleHistory, .notEnrolled)
        let facts = try Sched.habitFacts(store)
        XCTAssertEqual(facts.weekdays, [3, 5])
        XCTAssertEqual(facts.dueDate, newTime)
        XCTAssertEqual(facts.icon, "bed")
        XCTAssertFalse(facts.notification)
        try assertNoScheduleHistory(store, ids: ids)
    }

    func testB36DeleteBeforeEnrollmentWritesNoRevision() async throws {
        let store = try TxStore.memory(); try Sched.seedHabit(store)
        let ids = Sched.UUIDSequence()
        let outcome = try await Sched.repository(store, ids: ids).delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(outcome, .notEnrolled)
        XCTAssertEqual(try Sched.habitCount(store), 0)
        XCTAssertEqual(try Sched.archiveCount(store), 1)
        try assertNoScheduleHistory(store, ids: ids)
    }

    func testB37RestoreBeforeEnrollmentWritesNoRevision() async throws {
        let store = try TxStore.memory(); try Sched.seedHabit(store)
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(store, ids: ids)
        try await repository.delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 1, hour: 10))
        let outcome = try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 2, hour: 10))
        XCTAssertEqual(outcome, .notEnrolled)
        XCTAssertEqual(try Sched.habitCount(store), 1)
        XCTAssertEqual(try Sched.archiveCount(store), 0)
        try assertNoScheduleHistory(store, ids: ids)
    }

    func testMissingHabitOrArchiveWritesNothingAndReportsNoOutcome() async throws {
        let store = try Sched.enrolledStore()
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let deleted = try await repository.delete(id: Sched.otherUUID, effectiveAt: Sched.at(day: 1, hour: 10))
        let restored = try await repository.restoreDeletedHabit(id: Sched.otherUUID, effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertNil(deleted)
        XCTAssertNil(restored)
        XCTAssertEqual(try TxStore.state(store), before)
    }

    // MARK: B38-B46 - enrolled, healthy history

    func testB38TitleUpdateKeepsBaselineOpen() async throws {
        let store = try Sched.enrolledStore()
        let before = try Sched.rows(store)
        let ids = Sched.UUIDSequence()
        let result = try await Sched.repository(store, ids: ids)
            .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.title = "Gym (evening)"
                $0.description = "Back day"
                $0.tags = ["strength"]
                $0.iconColor = .blue
            }, effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(result.scheduleHistory, .revisionNotRequired)
        XCTAssertEqual(result.habit.title, "Gym (evening)")
        XCTAssertEqual(try Sched.habitFacts(store).title, "Gym (evening)")
        XCTAssertEqual(try Sched.rows(store), before)
        XCTAssertNil(before.first?.effectiveTo)
        XCTAssertEqual(ids.count, 0)
    }

    func testB39PriorityUpdateClosesBaselineAndOpensNextRevision() async throws {
        let at = Sched.at(day: 1, hour: 10)
        try await assertReplacement(at: at, expected: Sched.Payload(priority: BehaviorPriority.notUrgentAndNotImportant.rawValue)) { repository in
            try await repository.updatePriority(id: Sched.targetUUID, priority: .notUrgentAndNotImportant, effectiveAt: at).scheduleHistory
        }
    }

    func testB40WeekdayUpdateClosesAndOpens() async throws {
        let at = Sched.at(day: 1, hour: 10)
        try await assertReplacement(at: at, expected: Sched.Payload(mask: 0b001_0100)) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.repeating = [.tuesday, .thursday] },
                                                effectiveAt: at).scheduleHistory
        }
    }

    func testB41NotificationUpdateClosesAndOpens() async throws {
        let at = Sched.at(day: 1, hour: 10)
        try await assertReplacement(at: at, expected: Sched.Payload(hour: nil, minute: nil, notification: false)) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.isNotificationActivated = false },
                                                effectiveAt: at).scheduleHistory
        }
    }

    func testB42ScheduledTimeUpdateWithNotificationOnClosesAndOpens() async throws {
        let at = Sched.at(day: 1, hour: 10)
        try await assertReplacement(at: at, expected: Sched.Payload(hour: 18, minute: 15)) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID,
                                                metadata: Sched.metadata { $0.dueDate = Sched.at(day: 0, hour: 18, minute: 15) },
                                                effectiveAt: at).scheduleHistory
        }
    }

    func testB43OneTimeDueAtUpdateClosesAndOpens() async throws {
        let firstDue = Sched.at(day: 4, hour: 17)
        let secondDue = Sched.at(day: 6, hour: 9, minute: 5)
        let oneTime = Sched.Payload(taskType: "oneTime", mask: 0, hour: nil, minute: nil, dueAt: firstDue, notification: false)
        let store = try Sched.enrolledStore(habit: Sched.HabitSeed(type: .dueDate, weekdays: [], dueDate: firstDue, notification: false),
                                            baseline: Sched.RevisionSeed(payload: oneTime))
        let ids = Sched.UUIDSequence()
        let at = Sched.at(day: 1, hour: 10)
        let result = try await Sched.repository(store, ids: ids)
            .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.type = .dueDate
                $0.repeating = []
                $0.dueDate = secondDue
                $0.isNotificationActivated = false
            }, effectiveAt: at)
        XCTAssertEqual(result.scheduleHistory, .revisionApplied(ScheduleRevisionChange(closedRevisionID: Sched.baselineID,
                                                                                        openedRevisionID: Sched.changeID(1),
                                                                                        effectiveAt: at)))
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(try Sched.row(rows, Sched.baselineID).payload, oneTime)
        var expected = oneTime
        expected.dueAt = secondDue
        XCTAssertEqual(try Sched.row(rows, Sched.changeID(1)).payload, expected)
    }

    func testB44IconNameUpdateClosesAndOpens() async throws {
        let at = Sched.at(day: 1, hour: 10)
        try await assertReplacement(at: at, expected: Sched.Payload(icon: "bed")) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.icon = "bed" },
                                                effectiveAt: at).scheduleHistory
        }
    }

    func testB45TaskTypeUpdateClosesAndOpens() async throws {
        let at = Sched.at(day: 1, hour: 10)
        let expected = Sched.Payload(taskType: "oneTime", mask: 0, hour: nil, minute: nil, dueAt: Sched.reminder)
        try await assertReplacement(at: at, expected: expected) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.type = .dueDate },
                                                effectiveAt: at).scheduleHistory
        }
    }

    func testB46SubmittingTheSameRelevantValuesAgainAddsNoRevision() async throws {
        let store = try Sched.enrolledStore()
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(store, ids: ids)
        let change = Sched.metadata { $0.priority = .urgentButNotImportant; $0.repeating = [.saturday] }
        let first = try await repository.updateMetadata(id: Sched.targetUUID, metadata: change, effectiveAt: Sched.at(day: 1, hour: 10))
        guard case .revisionApplied = first.scheduleHistory else { return XCTFail("\(first.scheduleHistory)") }
        let afterFirst = try Sched.rows(store)

        let again = try await repository.updateMetadata(id: Sched.targetUUID, metadata: change, effectiveAt: Sched.at(day: 2, hour: 10))
        let priorityAgain = try await repository.updatePriority(id: Sched.targetUUID, priority: .urgentButNotImportant,
                                                                effectiveAt: Sched.at(day: 3, hour: 10))
        XCTAssertEqual(again.scheduleHistory, .revisionNotRequired)
        XCTAssertEqual(priorityAgain.scheduleHistory, .revisionNotRequired)
        XCTAssertEqual(try Sched.rows(store), afterFirst)
        XCTAssertEqual(afterFirst.count, 2)
        XCTAssertEqual(ids.count, 1)
    }

    func testHiddenClockChangeWithRemindersOffWritesNoRevision() async throws {
        // B13 end to end: reminders off, so the stored clock is not a timed commitment.
        let noClock = Sched.Payload(hour: nil, minute: nil, notification: false)
        let store = try Sched.enrolledStore(habit: Sched.HabitSeed(notification: false),
                                            baseline: Sched.RevisionSeed(payload: noClock))
        let before = try Sched.rows(store)
        let ids = Sched.UUIDSequence()
        let result = try await Sched.repository(store, ids: ids)
            .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.isNotificationActivated = false
                $0.dueDate = Sched.at(day: 2, hour: 21, minute: 43)
            }, effectiveAt: Sched.at(day: 2, hour: 21, minute: 43))
        XCTAssertEqual(result.scheduleHistory, .revisionNotRequired)
        XCTAssertEqual(try Sched.habitFacts(store).dueDate, Sched.at(day: 2, hour: 21, minute: 43), "the Habit itself still saves")
        XCTAssertEqual(try Sched.rows(store), before)
        XCTAssertEqual(ids.count, 0)
    }

    func testRevisionChainAcrossSeveralEditsIsContiguous() async throws {
        let store = try Sched.enrolledStore()
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let t1 = Sched.at(day: 1, hour: 10), t2 = Sched.at(day: 2, hour: 11), t3 = Sched.at(day: 5, hour: 7)
        _ = try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent, effectiveAt: t1)
        // Title only (priority stays what t1 set): no revision at t2.
        _ = try await repository.updateMetadata(id: Sched.targetUUID,
                                                metadata: Sched.metadata { $0.title = "Renamed"; $0.priority = .importantAndUrgent },
                                                effectiveAt: t2)
        _ = try await repository.updateMetadata(id: Sched.targetUUID,
                                                metadata: Sched.metadata { $0.priority = .importantAndUrgent; $0.icon = "bed" },
                                                effectiveAt: t3)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.logicalRevisionID), [Sched.baselineID, Sched.changeID(1), Sched.changeID(2)])
        XCTAssertEqual(rows.map(\.effectiveFrom), [Sched.trackingStartedAt, t1, t3])
        XCTAssertEqual(rows.map(\.effectiveTo), [t1, t3, nil])
        XCTAssertEqual(rows[2].payload, Sched.Payload(priority: BehaviorPriority.importantAndUrgent.rawValue, icon: "bed"))
    }

    // MARK: B63 - exact enrollment boundary

    func testB63ChangeExactlyAtTrackingStartedAtLeavesAZeroDurationBaseline() async throws {
        let store = try Sched.enrolledStore()
        let t = Sched.trackingStartedAt
        let result = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent, effectiveAt: t)
        XCTAssertEqual(result.scheduleHistory, .revisionApplied(ScheduleRevisionChange(closedRevisionID: Sched.baselineID,
                                                                                        openedRevisionID: Sched.changeID(1),
                                                                                        effectiveAt: t)))
        let rows = try Sched.rows(store)
        let baseline = try Sched.row(rows, Sched.baselineID)
        let next = try Sched.row(rows, Sched.changeID(1))
        // [T, T): no epsilon, no gap, no overlap; T belongs to the new revision.
        XCTAssertEqual(baseline.effectiveFrom, t)
        XCTAssertEqual(baseline.effectiveTo, t)
        XCTAssertEqual(next.effectiveFrom, t)
        XCTAssertNil(next.effectiveTo)
    }

    // MARK: B82 - device time zone never drives history

    func testB82DeviceTimeZoneDoesNotChangeTheRevisionSnapshot() async throws {
        let originalCurrent = TimeZone.current.identifier
        let dueAt = Sched.at(day: 0, hour: 18, minute: 45)
        var captured: [String: Sched.Row] = [:]
        var deviceOffsets: [String: Int] = [:]
        for deviceZone in ["Asia/Tokyo", "Europe/London"] {
            try await withDeviceTimeZone(deviceZone) {
                // Precondition: the process really runs in `deviceZone`, both as the system zone and the default zone.
                XCTAssertEqual(TimeZone.current.identifier, deviceZone)
                XCTAssertEqual(NSTimeZone.default.identifier, deviceZone)
                deviceOffsets[deviceZone] = TimeZone.current.secondsFromGMT(for: dueAt)
                let store = try Sched.enrolledStore()
                let result = try await Sched.repository(store, ids: Sched.UUIDSequence())
                    .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.dueDate = dueAt },
                                    effectiveAt: Sched.at(day: 1, hour: 10))
                guard case .revisionApplied = result.scheduleHistory else { return XCTFail("\(deviceZone): \(result.scheduleHistory)") }
                captured[deviceZone] = try Sched.row(try Sched.rows(store), Sched.changeID(1))
            }
        }
        // The two runs really had different device clocks for the reminder instant (JST +9 h, GMT +0 in January).
        XCTAssertEqual(deviceOffsets["Asia/Tokyo"], 9 * 3_600)
        XCTAssertEqual(deviceOffsets["Europe/London"], 0)
        XCTAssertEqual(TimeZone.current.identifier, originalCurrent, "the device zone is restored for later tests")

        let tokyo = try XCTUnwrap(captured["Asia/Tokyo"])
        let london = try XCTUnwrap(captured["Europe/London"])
        XCTAssertEqual(tokyo.payload, london.payload)
        XCTAssertEqual(tokyo.logicalRevisionID, london.logicalRevisionID)
        XCTAssertEqual(tokyo.effectiveFrom, london.effectiveFrom)
        // 18:45 in the profile's Los Angeles zone (Tokyo would read 11:45, London 02:45).
        XCTAssertEqual(tokyo.payload.hour, 18)
        XCTAssertEqual(tokyo.payload.minute, 45)
        XCTAssertEqual(tokyo.payload.timeZone, Sched.la)
    }

    // MARK: B83 - persistence round-trip through the production path

    func testB83RevisionsWrittenByTheProductionPathSurviveReopeningTheStore() async throws {
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("schedule-history.store")
        let editAt = Sched.at(day: 1, hour: 10)
        let createAt = Sched.at(day: 2, hour: 14, minute: 20)
        let oneTimeDue = Sched.at(day: 9, hour: 17, minute: 30)

        try await writeHistory(url: url, editAt: editAt, createAt: createAt, oneTimeDue: oneTimeDue)

        let reopened = try TxStore.disk(url)
        let target = try Sched.rows(reopened)
        XCTAssertEqual(target.count, 2)
        let baseline = try Sched.row(target, Sched.baselineID)
        XCTAssertEqual(baseline.effectiveFrom, Sched.trackingStartedAt)
        XCTAssertEqual(baseline.effectiveTo, editAt)
        XCTAssertEqual(baseline.payload, Sched.Payload())
        let edited = try Sched.row(target, Sched.changeID(1))
        XCTAssertEqual(edited.logicalRevisionID, "rev:v1:123e4567-e89b-12d3-a456-426614174000:change:aaaaaaaa-bbbb-cccc-dddd-000000000001")
        XCTAssertEqual(edited.effectiveFrom, editAt)
        XCTAssertNil(edited.effectiveTo)
        XCTAssertEqual(edited.payload, Sched.Payload(target: Sched.targetUUID, taskType: "repeating", mask: 0b100_0001,
                                                     hour: 6, minute: 5, dueAt: nil, timeZone: Sched.la, calendar: "gregorian",
                                                     priority: BehaviorPriority.importantAndUrgent.rawValue, icon: "bed",
                                                     notification: true, schemaVersion: 1))

        let created = try Sched.rows(reopened, target: Sched.otherUUID)
        XCTAssertEqual(created.count, 1)
        let first = try XCTUnwrap(created.first)
        XCTAssertEqual(first.logicalRevisionID, Sched.changeID(2, target: Sched.otherText))
        XCTAssertEqual(first.effectiveFrom, createAt)
        XCTAssertNil(first.effectiveTo)
        XCTAssertEqual(first.payload, Sched.Payload(target: Sched.otherUUID, taskType: "oneTime", mask: 0, hour: nil, minute: nil,
                                                    dueAt: oneTimeDue, timeZone: Sched.la, calendar: "gregorian",
                                                    priority: BehaviorPriority.urgentButNotImportant.rawValue, icon: nil,
                                                    notification: true, schemaVersion: 1))
    }

    // MARK: - Helpers

    /// Runs `body` with the process's device time zone set to `identifier`.
    ///
    /// Foundation keeps two zones: `TimeZone.current` (the system zone, read from `TZFILE`/`TZ` and
    /// cached until `NSTimeZone.resetSystemTimeZone()`), and `NSTimeZone.default`, which is separate
    /// and does not change `TimeZone.current`. Both are switched here and restored afterwards.
    private func withDeviceTimeZone(_ identifier: String, _ body: () async throws -> Void) async throws {
        let zone = try XCTUnwrap(TimeZone(identifier: identifier))
        let savedTZ = getenv("TZ").map { String(cString: $0) }
        let savedTZFile = getenv("TZFILE").map { String(cString: $0) }
        let savedDefault = NSTimeZone.default
        defer {
            if let savedTZ { _ = setenv("TZ", savedTZ, 1) } else { _ = unsetenv("TZ") }
            if let savedTZFile { _ = setenv("TZFILE", savedTZFile, 1) } else { _ = unsetenv("TZFILE") }
            NSTimeZone.resetSystemTimeZone()
            NSTimeZone.default = savedDefault
        }
        _ = unsetenv("TZFILE")
        _ = setenv("TZ", identifier, 1)
        NSTimeZone.resetSystemTimeZone()
        NSTimeZone.default = zone
        try await body()
    }

    private func writeHistory(url: URL, editAt: Date, createAt: Date, oneTimeDue: Date) async throws {
        let store = try TxStore.disk(url)
        try Sched.seedProfile(store)
        try Sched.seedHabit(store)
        try Sched.seedRevision(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let edit = try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
            $0.priority = .importantAndUrgent
            $0.repeating = [.sunday, .saturday]
            $0.dueDate = Sched.at(day: 0, hour: 6, minute: 5)
            $0.icon = "bed"
        }, effectiveAt: editAt)
        let create = try await repository.createHabit(id: Sched.otherUUID, metadata: Sched.metadata {
            $0.title = "File taxes"
            $0.icon = nil
            $0.priority = .urgentButNotImportant
            $0.type = .dueDate
            $0.repeating = []
            $0.dueDate = oneTimeDue
        }, effectiveAt: createAt)
        guard case .revisionApplied = edit.scheduleHistory, case .revisionApplied = create.scheduleHistory else {
            return XCTFail("expected applied history: \(edit.scheduleHistory) / \(create.scheduleHistory)")
        }
    }

    /// Runs `mutation` on a fresh healthy enrolled store at `at` and asserts the exact close/open.
    private func assertReplacement(at: Date, expected: Sched.Payload,
                                   file: StaticString = #filePath, line: UInt = #line,
                                   _ mutation: (HabitsRepositorySwiftData) async throws -> ScheduleHistoryOutcome) async throws {
        let store = try Sched.enrolledStore()
        let recordsBefore = try Sched.recordRowCount(store)
        let ids = Sched.UUIDSequence()
        let outcome = try await mutation(Sched.repository(store, ids: ids))
        XCTAssertEqual(outcome, .revisionApplied(ScheduleRevisionChange(closedRevisionID: Sched.baselineID,
                                                                        openedRevisionID: Sched.changeID(1),
                                                                        effectiveAt: at)), file: file, line: line)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.count, 2, file: file, line: line)
        let baseline = try Sched.row(rows, Sched.baselineID)
        XCTAssertEqual(baseline.effectiveFrom, Sched.trackingStartedAt, file: file, line: line)
        XCTAssertEqual(baseline.effectiveTo, at, file: file, line: line)
        XCTAssertEqual(baseline.payload, Sched.Payload(), "closing never rewrites the old payload", file: file, line: line)
        let next = try Sched.row(rows, Sched.changeID(1))
        XCTAssertEqual(next.effectiveFrom, at, file: file, line: line)
        XCTAssertNil(next.effectiveTo, file: file, line: line)
        XCTAssertEqual(next.payload, expected, file: file, line: line)
        XCTAssertEqual(ids.count, 1, file: file, line: line)
        XCTAssertEqual(try Sched.recordRowCount(store), recordsBefore, file: file, line: line)
        XCTAssertEqual(try Sched.otherGamificationCounts(store),
                       Sched.OtherGamificationCounts(occurrences: 0, events: 0, ledger: 0, profiles: 1), file: file, line: line)
    }

    private func assertNoScheduleHistory(_ store: ModelContainer, ids: Sched.UUIDSequence,
                                         file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try Sched.rows(store, target: nil).count, 0, file: file, line: line)
        XCTAssertEqual(ids.count, 0, file: file, line: line)
        try Phase2TestStore.assertNewTablesEmpty(ModelContext(store), file: file, line: line)
    }
}
