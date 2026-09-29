import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4B B1-B25: schedule snapshot normalization, weekday mask and the pure revision planner.
/// No store is opened: the planner sees only values.
final class BehaviorScheduleRevisionPlannerTests: XCTestCase {
    private let planner = BehaviorScheduleRevisionPlanner()

    // MARK: B1-B5 - identical planning payload, non-relevant fields

    func testB1IdenticalSnapshotsNeedNoRevision() {
        let current = snapshot(of: source())
        let same = snapshot(of: source())
        XCTAssertEqual(current, same)
        XCTAssertFalse(planner.requiresRevision(current: current, proposed: same))
        XCTAssertEqual(planner.plan(.update(current: current, proposed: same), history: [openFacts(current)],
                                    trackingStartedAt: Sched.trackingStartedAt, effectiveAt: Sched.at(day: 1, hour: 10)),
                       .noRevisionRequired)
    }

    func testB2TitleOnlyChangeGivesEqualSnapshots() {
        assertNotRevisionRelevant { $0.title = "Gym (evening)" }
    }

    func testB3DescriptionOnlyChangeGivesEqualSnapshots() {
        assertNotRevisionRelevant { $0.descriptionText = "Legs, back and core" }
    }

    func testB4TagsOnlyChangeGivesEqualSnapshots() {
        assertNotRevisionRelevant { $0.tags = ["strength", "morning", "gym"] }
    }

    func testB5IconColorOnlyChangeGivesEqualSnapshots() {
        assertNotRevisionRelevant { $0.iconColorHex = "#00FF00FF" }
    }

    // MARK: B6-B16 - every revision-relevant field

    func testB6PriorityChangeRequiresRevision() {
        assertRevisionRelevant { $0.priority = .notUrgentAndNotImportant }
    }

    func testB7SelectedWeekdayChangeRequiresRevision() {
        assertRevisionRelevant { $0.weekdays = [.tuesday, .thursday] }
    }

    func testB8TaskTypeChangeRequiresRevision() {
        assertRevisionRelevant { $0.taskType = .oneTime }
    }

    func testB9IconNameChangeRequiresRevision() {
        assertRevisionRelevant { $0.iconName = "bed" }
    }

    func testB10NotificationOffToOnRequiresRevision() {
        let off = snapshot(of: source { $0.notificationEnabled = false })
        let on = snapshot(of: source())
        XCTAssertNil(off.scheduledHour)
        XCTAssertNil(off.scheduledMinute)
        XCTAssertEqual(on.scheduledHour, 7)
        XCTAssertEqual(on.scheduledMinute, 30)
        XCTAssertTrue(planner.requiresRevision(current: off, proposed: on))
    }

    func testB11NotificationOnToOffRequiresRevision() {
        let on = snapshot(of: source())
        let off = snapshot(of: source { $0.notificationEnabled = false })
        XCTAssertTrue(planner.requiresRevision(current: on, proposed: off))
        XCTAssertEqual(off.notificationEnabled, false)
    }

    func testB12RepeatingClockChangeWithNotificationOnRequiresRevision() {
        let morning = snapshot(of: source())
        let evening = snapshot(of: source { $0.dueDate = Sched.at(day: 0, hour: 18, minute: 15) })
        XCTAssertEqual(evening.scheduledHour, 18)
        XCTAssertEqual(evening.scheduledMinute, 15)
        XCTAssertTrue(planner.requiresRevision(current: morning, proposed: evening))
    }

    func testB13RepeatingClockNoiseWithNotificationOffIsNormalizedAway() {
        let first = snapshot(of: source { $0.notificationEnabled = false })
        // A different stored clock, and even a different day, while reminders stay off.
        let second = snapshot(of: source {
            $0.notificationEnabled = false
            $0.dueDate = Sched.at(day: 3, hour: 21, minute: 43)
        })
        XCTAssertNil(first.scheduledHour)
        XCTAssertNil(first.scheduledMinute)
        XCTAssertNil(second.scheduledHour)
        XCTAssertNil(second.scheduledMinute)
        XCTAssertNil(second.dueAt)
        XCTAssertEqual(first, second)
        XCTAssertFalse(planner.requiresRevision(current: first, proposed: second))
    }

    func testB14OneTimeDueAtChangeRequiresRevision() {
        let firstDue = Sched.at(day: 4, hour: 17)
        let secondDue = Sched.at(day: 5, hour: 12, minute: 5)
        let first = snapshot(of: source { $0.taskType = .oneTime; $0.dueDate = firstDue })
        let second = snapshot(of: source { $0.taskType = .oneTime; $0.dueDate = secondDue })
        XCTAssertEqual(first.dueAt, firstDue)
        XCTAssertEqual(second.dueAt, secondDue)
        XCTAssertTrue(planner.requiresRevision(current: first, proposed: second))
    }

    func testB15SchedulingTimeZoneChangeRequiresRevision() {
        let losAngeles = snapshot(of: source(), policy: policy(Sched.la))
        let tokyo = snapshot(of: source(), policy: policy("Asia/Tokyo"))
        XCTAssertEqual(tokyo.schedulingTimeZoneIdentifier, "Asia/Tokyo")
        XCTAssertTrue(planner.requiresRevision(current: losAngeles, proposed: tokyo))

        // The identifier alone is revision-relevant, even with an identical clock.
        var renamed = losAngeles
        renamed.schedulingTimeZoneIdentifier = "US/Pacific"
        XCTAssertTrue(planner.requiresRevision(current: losAngeles, proposed: renamed))
    }

    func testB16SchedulingCalendarChangeRequiresRevision() {
        let gregorian = snapshot(of: source())
        var other = gregorian
        other.schedulingCalendarIdentifier = "iso8601"
        XCTAssertEqual(gregorian.schedulingCalendarIdentifier, "gregorian")
        XCTAssertTrue(planner.requiresRevision(current: gregorian, proposed: other))
    }

    // MARK: Normalization, exactly

    func testRepeatingSnapshotIsNormalizedExactly() {
        let value = snapshot(of: source())
        XCTAssertEqual(value, BehaviorScheduleSnapshot(targetID: Sched.target, taskType: .repeating,
                                                       selectedWeekdaysMask: 42, scheduledHour: 7, scheduledMinute: 30,
                                                       dueAt: nil, schedulingTimeZoneIdentifier: Sched.la,
                                                       schedulingCalendarIdentifier: "gregorian",
                                                       priority: .importantButNotUrgent, iconName: "atom",
                                                       notificationEnabled: true))
    }

    func testOneTimeSnapshotKeepsDueAtWithoutMaskOrClockEvenWithNotificationOff() {
        let due = Sched.at(day: 2, hour: 16, minute: 45)
        let value = snapshot(of: source {
            $0.taskType = .oneTime
            $0.dueDate = due
            $0.notificationEnabled = false
            $0.weekdays = [.monday, .saturday] // leftover UI weekdays never reach one-time history
        })
        XCTAssertEqual(value, BehaviorScheduleSnapshot(targetID: Sched.target, taskType: .oneTime,
                                                       selectedWeekdaysMask: 0, scheduledHour: nil, scheduledMinute: nil,
                                                       dueAt: due, schedulingTimeZoneIdentifier: Sched.la,
                                                       schedulingCalendarIdentifier: "gregorian",
                                                       priority: .importantButNotUrgent, iconName: "atom",
                                                       notificationEnabled: false))
    }

    func testClockIsReadInThePolicyTimeZone() {
        // 07:30 in Los Angeles is 00:30 the next day in Tokyo (PST = UTC-8, JST = UTC+9).
        XCTAssertEqual(snapshot(of: source(), policy: policy("Asia/Tokyo")).scheduledHour, 0)
        XCTAssertEqual(snapshot(of: source(), policy: policy("Asia/Tokyo")).scheduledMinute, 30)
        XCTAssertEqual(snapshot(of: source(), policy: policy("UTC")).scheduledHour, 15)
    }

    func testPersistedRowMapsExactlyLikeTheAppReadsIt() {
        let row = habitRow { $0.priorityRaw = 99; $0.typeRaw = 99; $0.repeatingWeekdays = [0, 2, 8, 4, 2] }
        let mapped = BehaviorScheduleRevisionMapper.source(from: row)
        XCTAssertEqual(mapped.priority, .importantAndUrgent, "unknown priority reads as HabitMapper.toDomain reads it")
        XCTAssertEqual(mapped.taskType, .repeating, "unknown type reads as HabitMapper.toDomain reads it")
        XCTAssertEqual(mapped.weekdays, [.monday, .wednesday], "values outside 1...7 are ignored")
        XCTAssertEqual(BehaviorScheduleRevisionMapper.source(from: habitRow { $0.typeRaw = HabitType.dueDate.rawValue }).taskType, .oneTime)
    }

    // MARK: B17-B25 - weekday mask

    func testB17SundayIsBit0() { XCTAssertEqual(mask([.sunday]), 0b000_0001) }
    func testB18MondayIsBit1() { XCTAssertEqual(mask([.monday]), 0b000_0010) }
    func testB19TuesdayIsBit2() { XCTAssertEqual(mask([.tuesday]), 0b000_0100) }
    func testB20WednesdayIsBit3() { XCTAssertEqual(mask([.wednesday]), 0b000_1000) }
    func testB21ThursdayIsBit4() { XCTAssertEqual(mask([.thursday]), 0b001_0000) }
    func testB22FridayIsBit5() { XCTAssertEqual(mask([.friday]), 0b010_0000) }
    func testB23SaturdayIsBit6() { XCTAssertEqual(mask([.saturday]), 0b100_0000) }

    func testB24MondayWednesdayFridayMaskIsExact() {
        XCTAssertEqual(mask([.monday, .wednesday, .friday]), (1 << 1) | (1 << 3) | (1 << 5))
        XCTAssertEqual(mask([.monday, .wednesday, .friday]), 42)
        XCTAssertEqual(BehaviorScheduleSnapshot.weekdayMask(BehaviorWeekday.allCases), 127)
        XCTAssertEqual(BehaviorScheduleSnapshot.weekdayMask([BehaviorWeekday]()), 0)
        for weekday in BehaviorWeekday.allCases {
            XCTAssertEqual(BehaviorScheduleSnapshot.weekdayMask([weekday]), 1 << (weekday.rawValue - 1), "\(weekday)")
        }
    }

    func testB25IterationOrderAndDuplicatesCannotChangeTheMask() {
        let orders: [[BehaviorWeekday]] = [[.monday, .wednesday, .friday], [.friday, .monday, .wednesday],
                                           [.wednesday, .friday, .monday], [.friday, .friday, .monday, .wednesday, .monday]]
        for order in orders {
            XCTAssertEqual(mask(order), 42, "\(order)")
        }
        XCTAssertEqual(BehaviorScheduleSnapshot.weekdayMask(Set([BehaviorWeekday.friday, .wednesday, .monday])), 42)
        // Through the whole row -> snapshot path, stored array order does not matter either.
        let forward = snapshot(of: BehaviorScheduleRevisionMapper.source(from: habitRow { $0.repeatingWeekdays = [2, 4, 6] }))
        let backward = snapshot(of: BehaviorScheduleRevisionMapper.source(from: habitRow { $0.repeatingWeekdays = [6, 4, 2, 6] }))
        XCTAssertEqual(forward, backward)
        XCTAssertEqual(forward.selectedWeekdaysMask, 42)
    }

    // MARK: Planner history rules (pure)

    func testUpdateWithoutOpenRevisionIsDeferred() {
        let current = snapshot(of: source())
        let closed = revision(current, from: Sched.trackingStartedAt, to: Sched.at(day: 1, hour: 8))
        XCTAssertEqual(plan(.update(current: current, proposed: changedPriority(current)), history: []),
                       .deferHistory(.missingOpenRevision))
        XCTAssertEqual(plan(.update(current: current, proposed: changedPriority(current)), history: [closed]),
                       .deferHistory(.missingOpenRevision))
    }

    func testSeveralOpenRevisionsAreNeverResolvedEvenWhenIdentical() {
        let current = snapshot(of: source())
        let duplicates = [openFacts(current), openFacts(current)]
        XCTAssertEqual(plan(.update(current: current, proposed: changedPriority(current)), history: duplicates),
                       .deferHistory(.multipleOpenRevisions(count: 2)))
        XCTAssertEqual(plan(.update(current: current, proposed: current), history: duplicates),
                       .deferHistory(.multipleOpenRevisions(count: 2)))
        XCTAssertEqual(plan(.delete(current: current), history: duplicates),
                       .deferHistory(.multipleOpenRevisions(count: 2)))
        XCTAssertEqual(plan(.restore(proposed: current), history: duplicates),
                       .deferHistory(.multipleOpenRevisions(count: 2)))
    }

    func testOpenRevisionThatNoLongerDescribesTheHabitIsDeferredEvenIfTheEditMatchesIt() {
        let stored = snapshot(of: source())
        let current = changedPriority(stored)
        // Reverting the Habit to the stored payload still does not repair the missing interval.
        XCTAssertEqual(plan(.update(current: current, proposed: stored), history: [openFacts(stored)]),
                       .deferHistory(.currentRevisionDoesNotMatchCurrentHabit))
        XCTAssertEqual(plan(.delete(current: current), history: [openFacts(stored)]),
                       .deferHistory(.currentRevisionDoesNotMatchCurrentHabit))
    }

    func testUndecodableOpenRevisionIsNotTrusted() {
        let current = snapshot(of: source())
        let unreadable = BehaviorScheduleRevisionFacts(logicalRevisionID: Sched.baselineID, effectiveFrom: Sched.trackingStartedAt,
                                                       effectiveTo: nil, snapshot: nil)
        XCTAssertEqual(plan(.update(current: current, proposed: current), history: [unreadable]),
                       .deferHistory(.currentRevisionDoesNotMatchCurrentHabit))
    }

    func testRelevantUpdateReplacesTheOpenRevisionAtEffectiveAt() {
        let current = snapshot(of: source())
        let proposed = changedPriority(current)
        let at = Sched.at(day: 1, hour: 10)
        XCTAssertEqual(plan(.update(current: current, proposed: proposed), history: [openFacts(current)], at: at),
                       .replaceOpenRevision(closedRevisionID: Sched.baselineID, at: at, next: proposed))
    }

    func testMutationBeforeEnrollmentIsDeferredOnlyWhenItWouldWrite() {
        let current = snapshot(of: source())
        let early = Sched.at(day: 0, hour: 8)
        XCTAssertEqual(plan(.update(current: current, proposed: changedPriority(current)), history: [openFacts(current)], at: early),
                       .deferHistory(.mutationPredatesEnrollment(trackingStartedAt: Sched.trackingStartedAt, effectiveAt: early)))
        XCTAssertEqual(plan(.create(proposed: current), history: [], at: early),
                       .deferHistory(.mutationPredatesEnrollment(trackingStartedAt: Sched.trackingStartedAt, effectiveAt: early)))
        // Nothing to write: trustworthy history stays trustworthy.
        XCTAssertEqual(plan(.update(current: current, proposed: current), history: [openFacts(current)], at: early),
                       .noRevisionRequired)
    }

    func testBoundaryEarlierThanRecordedHistoryIsDeferredAndEqualBoundaryIsAllowed() {
        let current = snapshot(of: source())
        let edit = Sched.at(day: 2, hour: 9)
        let history = [revision(current, from: Sched.trackingStartedAt, to: edit, id: Sched.baselineID),
                       revision(current, from: edit, to: nil, id: Sched.changeID(1))]
        let earlier = Sched.at(day: 1, hour: 9)
        XCTAssertEqual(plan(.update(current: current, proposed: changedPriority(current)), history: history, at: earlier),
                       .deferHistory(.revisionChronologyConflict(latestBoundary: edit, effectiveAt: earlier)))
        XCTAssertEqual(plan(.update(current: current, proposed: changedPriority(current)), history: history, at: edit),
                       .replaceOpenRevision(closedRevisionID: Sched.changeID(1), at: edit, next: changedPriority(current)))
        // History order does not matter.
        XCTAssertEqual(plan(.update(current: current, proposed: changedPriority(current)), history: history.reversed(), at: earlier),
                       .deferHistory(.revisionChronologyConflict(latestBoundary: edit, effectiveAt: earlier)))
    }

    func testDeleteClosesTheTrustedOpenRevision() {
        let current = snapshot(of: source())
        let at = Sched.at(day: 3, hour: 20)
        XCTAssertEqual(plan(.delete(current: current), history: [openFacts(current)], at: at),
                       .closeOpenRevision(closedRevisionID: Sched.baselineID, at: at))
        XCTAssertEqual(plan(.delete(current: current), history: [], at: at), .deferHistory(.missingOpenRevision))
    }

    func testCreateAndRestoreOpenOnlyWithoutAnOpenRevisionAndAfterRecordedHistory() {
        let proposed = snapshot(of: source())
        let deletedAt = Sched.at(day: 2, hour: 12)
        let closed = revision(proposed, from: Sched.trackingStartedAt, to: deletedAt)
        let at = Sched.at(day: 4, hour: 8)
        XCTAssertEqual(plan(.create(proposed: proposed), history: [], at: at), .openRevision(at: at, next: proposed))
        XCTAssertEqual(plan(.restore(proposed: proposed), history: [closed], at: at), .openRevision(at: at, next: proposed))
        XCTAssertEqual(plan(.restore(proposed: proposed), history: [closed], at: deletedAt), .openRevision(at: deletedAt, next: proposed))
        XCTAssertEqual(plan(.restore(proposed: proposed), history: [openFacts(proposed)], at: at), .deferHistory(.openRevisionAlreadyExists))
        XCTAssertEqual(plan(.create(proposed: proposed), history: [openFacts(proposed)], at: at), .deferHistory(.openRevisionAlreadyExists))
        let early = Sched.at(day: 1, hour: 12)
        XCTAssertEqual(plan(.restore(proposed: proposed), history: [closed], at: early),
                       .deferHistory(.revisionChronologyConflict(latestBoundary: deletedAt, effectiveAt: early)))
    }

    func testPlanIsDeterministic() {
        let current = snapshot(of: source())
        let mutation = BehaviorScheduleMutation.update(current: current, proposed: changedPriority(current))
        let first = plan(mutation, history: [openFacts(current)])
        for _ in 0..<5 {
            XCTAssertEqual(BehaviorScheduleRevisionPlanner().plan(mutation, history: [openFacts(current)],
                                                                  trackingStartedAt: Sched.trackingStartedAt,
                                                                  effectiveAt: Sched.at(day: 1, hour: 10)), first)
        }
    }

    // MARK: Enrollment resolution (pure)

    func testEnrollmentResolutionFollowsStoredProfileFactsOnly() {
        let enrolled = BehaviorScheduleProfileFacts(trackingStartedAt: Sched.trackingStartedAt,
                                                    schedulingTimeZoneIdentifier: Sched.la,
                                                    schedulingCalendarIdentifier: "gregorian")
        let unenrolled = BehaviorScheduleProfileFacts(trackingStartedAt: nil, schedulingTimeZoneIdentifier: nil,
                                                      schedulingCalendarIdentifier: nil)
        XCTAssertEqual(resolve([], history: false), .notEnrolled)
        XCTAssertEqual(resolve([], history: true), .unavailable(.orphanRevisionHistory))
        XCTAssertEqual(resolve([unenrolled], history: false), .notEnrolled)
        XCTAssertEqual(resolve([unenrolled], history: true), .unavailable(.orphanRevisionHistory))
        XCTAssertEqual(resolve([enrolled, enrolled], history: false), .unavailable(.multipleProfiles(count: 2)))
        XCTAssertEqual(resolve([enrolled, unenrolled], history: true), .unavailable(.multipleProfiles(count: 2)))

        var badZone = enrolled; badZone.schedulingTimeZoneIdentifier = "Mars/Olympus_Mons"
        var noZone = enrolled; noZone.schedulingTimeZoneIdentifier = nil
        var emptyZone = enrolled; emptyZone.schedulingTimeZoneIdentifier = ""
        var iso = enrolled; iso.schedulingCalendarIdentifier = "iso8601"
        var noCalendar = enrolled; noCalendar.schedulingCalendarIdentifier = nil
        XCTAssertEqual(resolve([badZone], history: false), .unavailable(.invalidSchedulingTimeZone("Mars/Olympus_Mons")))
        XCTAssertEqual(resolve([noZone], history: false), .unavailable(.invalidSchedulingTimeZone(nil)))
        XCTAssertEqual(resolve([emptyZone], history: false), .unavailable(.invalidSchedulingTimeZone("")))
        XCTAssertEqual(resolve([iso], history: false), .unavailable(.unsupportedSchedulingCalendar("iso8601")))
        XCTAssertEqual(resolve([noCalendar], history: false), .unavailable(.unsupportedSchedulingCalendar(nil)))

        guard case let .enrolled(policy) = resolve([enrolled], history: true) else {
            return XCTFail("expected enrollment")
        }
        XCTAssertEqual(policy.trackingStartedAt, Sched.trackingStartedAt)
        XCTAssertEqual(policy.timeZoneIdentifier, Sched.la)
        XCTAssertEqual(policy.calendarIdentifier, "gregorian")
        XCTAssertEqual(policy.calendar.identifier, .gregorian)
        XCTAssertEqual(policy.calendar.timeZone.identifier, Sched.la)
    }

    func testEnrolledResolutionDoesNotQueryRevisionHistory() {
        var asked = 0
        let facts = BehaviorScheduleProfileFacts(trackingStartedAt: Sched.trackingStartedAt,
                                                 schedulingTimeZoneIdentifier: Sched.la,
                                                 schedulingCalendarIdentifier: "gregorian")
        _ = BehaviorScheduleEnrollment.resolve(profiles: [facts], revisionHistoryExists: { asked += 1; return true })
        XCTAssertEqual(asked, 0)
    }

    // MARK: - Helpers

    private func policy(_ zone: String = Sched.la) -> BehaviorSchedulingPolicy {
        let facts = BehaviorScheduleProfileFacts(trackingStartedAt: Sched.trackingStartedAt,
                                                 schedulingTimeZoneIdentifier: zone,
                                                 schedulingCalendarIdentifier: "gregorian")
        guard case let .enrolled(policy) = BehaviorScheduleEnrollment.resolve(profiles: [facts], revisionHistoryExists: { false }) else {
            preconditionFailure("fixture policy \(zone) must be valid")
        }
        return policy
    }

    /// Concretely typed entry to the generic mask, so array literals of implicit members infer.
    private func mask(_ weekdays: [BehaviorWeekday]) -> Int {
        BehaviorScheduleSnapshot.weekdayMask(weekdays)
    }

    private func resolve(_ profiles: [BehaviorScheduleProfileFacts], history: Bool) -> BehaviorScheduleEnrollment {
        BehaviorScheduleEnrollment.resolve(profiles: profiles, revisionHistoryExists: { history })
    }

    /// Default: the facts of `Sched.HabitSeed()`.
    private func source(_ change: (inout BehaviorScheduleSource) -> Void = { _ in }) -> BehaviorScheduleSource {
        var value = BehaviorScheduleSource(targetID: Sched.target, taskType: .repeating,
                                           weekdays: [.monday, .wednesday, .friday], dueDate: Sched.reminder,
                                           notificationEnabled: true, priority: .importantButNotUrgent, iconName: "atom")
        change(&value)
        return value
    }

    private func snapshot(of source: BehaviorScheduleSource, policy: BehaviorSchedulingPolicy? = nil) -> BehaviorScheduleSnapshot {
        BehaviorScheduleSnapshot.normalized(source, policy: policy ?? self.policy())
    }

    private func changedPriority(_ value: BehaviorScheduleSnapshot) -> BehaviorScheduleSnapshot {
        var changed = value
        changed.priority = .notUrgentAndNotImportant
        return changed
    }

    private func openFacts(_ value: BehaviorScheduleSnapshot) -> BehaviorScheduleRevisionFacts {
        revision(value, from: Sched.trackingStartedAt, to: nil)
    }

    private func revision(_ value: BehaviorScheduleSnapshot, from: Date, to: Date?,
                          id: String = Sched.baselineID) -> BehaviorScheduleRevisionFacts {
        BehaviorScheduleRevisionFacts(logicalRevisionID: id, effectiveFrom: from, effectiveTo: to, snapshot: value)
    }

    private func plan(_ mutation: BehaviorScheduleMutation, history: [BehaviorScheduleRevisionFacts],
                      at: Date = Sched.at(day: 1, hour: 10)) -> BehaviorScheduleRevisionPlan {
        planner.plan(mutation, history: history, trackingStartedAt: Sched.trackingStartedAt, effectiveAt: at)
    }

    /// An unmanaged Habit row with the default seed's values (never inserted into a store).
    private func habitRow(_ change: (HabitSD) -> Void = { _ in }) -> HabitSD {
        let row = HabitSD(id: Sched.targetUUID, icon: "atom", iconColorHex: "#FF0000FF", title: "Gym",
                          descriptionText: "Legs", tags: ["health"],
                          priorityRaw: PriorityEisenhower.importantButNotUrgent.rawValue,
                          typeRaw: HabitType.repeating.rawValue, repeatingWeekdays: [2, 4, 6],
                          dueDate: Sched.reminder, notificationActivated: true, records: [])
        change(row)
        return row
    }

    /// The change reaches only the Habit row fields no revision may depend on.
    private func assertNotRevisionRelevant(_ change: (HabitSD) -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let before = snapshot(of: BehaviorScheduleRevisionMapper.source(from: habitRow()))
        let after = snapshot(of: BehaviorScheduleRevisionMapper.source(from: habitRow(change)))
        XCTAssertEqual(before, after, file: file, line: line)
        XCTAssertFalse(planner.requiresRevision(current: before, proposed: after), file: file, line: line)
        XCTAssertEqual(plan(.update(current: before, proposed: after), history: [openFacts(before)]), .noRevisionRequired,
                       file: file, line: line)
    }

    private func assertRevisionRelevant(_ change: (inout BehaviorScheduleSource) -> Void,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let before = snapshot(of: source())
        let after = snapshot(of: source(change))
        XCTAssertNotEqual(before, after, file: file, line: line)
        XCTAssertTrue(planner.requiresRevision(current: before, proposed: after), file: file, line: line)
        let at = Sched.at(day: 1, hour: 10)
        XCTAssertEqual(plan(.update(current: before, proposed: after), history: [openFacts(before)], at: at),
                       .replaceOpenRevision(closedRevisionID: Sched.baselineID, at: at, next: after), file: file, line: line)
    }
}
