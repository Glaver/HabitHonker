import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4B B50-B62: when schedule history cannot be extended safely, the user's Habit mutation is
/// still saved, every revision row stays exactly as it was, nothing is fabricated, and the typed
/// reason is reported (v1.1.2 ADR 4.9).
@MainActor
final class BehaviorScheduleHistoryConflictTests: XCTestCase {

    // MARK: B50-B53 - the open revision must describe the Habit as it was before the mutation

    func testB50MatchingOpenRevisionAllowsTheRevision() async throws {
        let store = try Sched.enrolledStore()
        let at = Sched.at(day: 1, hour: 10)
        let result = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.repeating = [.monday] }, effectiveAt: at)
        XCTAssertEqual(result.scheduleHistory, .revisionApplied(ScheduleRevisionChange(closedRevisionID: Sched.baselineID,
                                                                                        openedRevisionID: Sched.changeID(1),
                                                                                        effectiveAt: at)))
    }

    func testB51PriorityAlreadyDifferentFromOpenRevisionDefersHistoryButSavesTheEdit() async throws {
        // The Habit says Not Important / Not Urgent; the open revision still says Important / Not Urgent.
        let store = try Sched.enrolledStore(habit: Sched.HabitSeed(priority: .notUrgentAndNotImportant))
        try await assertDeferred(store, .currentRevisionDoesNotMatchCurrentHabit) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.title = "Gym (renamed)"
                $0.priority = .importantAndUrgent
            }, effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        let facts = try Sched.habitFacts(store)
        XCTAssertEqual(facts.title, "Gym (renamed)")
        XCTAssertEqual(facts.priorityRaw, PriorityEisenhower.importantAndUrgent.rawValue)
    }

    func testB52WeekdaysAlreadyDifferentFromOpenRevisionDefersHistoryButSavesTheEdit() async throws {
        let store = try Sched.enrolledStore(habit: Sched.HabitSeed(weekdays: [3, 5]))
        try await assertDeferred(store, .currentRevisionDoesNotMatchCurrentHabit) { repository in
            try await repository.updatePriority(id: Sched.targetUUID, priority: .urgentButNotImportant,
                                                effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        XCTAssertEqual(try Sched.habitFacts(store).priorityRaw, PriorityEisenhower.urgentButNotImportant.rawValue)
    }

    func testB53NotificationOrTimeAlreadyDifferentFromOpenRevisionDefersHistoryButSavesTheEdit() async throws {
        let movedClock = try Sched.enrolledStore(habit: Sched.HabitSeed(dueDate: Sched.at(day: 0, hour: 8)))
        try await assertDeferred(movedClock, .currentRevisionDoesNotMatchCurrentHabit) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.icon = "bed"
                $0.dueDate = Sched.at(day: 0, hour: 8)
            }, effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        XCTAssertEqual(try Sched.habitFacts(movedClock).icon, "bed")

        let remindersOff = try Sched.enrolledStore(habit: Sched.HabitSeed(notification: false))
        try await assertDeferred(remindersOff, .currentRevisionDoesNotMatchCurrentHabit) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.icon = "bed" },
                                                effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        XCTAssertTrue(try Sched.habitFacts(remindersOff).notification)
    }

    func testDeferredEditLeavesHistoryBehindAndLaterEditsStayDeferredUntilReconciled() async throws {
        // 1. An unusable profile policy defers the first priority edit.
        let store = try TxStore.memory()
        try Sched.seedProfile(store, timeZone: "Not/AZone")
        try Sched.seedHabit(store)
        try Sched.seedRevision(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let first = try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent,
                                                        effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(first.scheduleHistory, .revisionDeferred(.invalidSchedulingTimeZone("Not/AZone")))

        // 2. Even after the policy becomes usable, the next edit must not paper over the missing interval.
        let context = ModelContext(store)
        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<GamificationProfileSD>()).first)
        profile.schedulingTimeZoneIdentifier = Sched.la
        try context.save()
        let revisionsBefore = try Sched.revisionState(store)
        let second = try await repository.updateMetadata(id: Sched.targetUUID,
                                                         metadata: Sched.metadata { $0.priority = .importantAndUrgent; $0.icon = "bed" },
                                                         effectiveAt: Sched.at(day: 2, hour: 10))
        XCTAssertEqual(second.scheduleHistory, .revisionDeferred(.currentRevisionDoesNotMatchCurrentHabit))
        XCTAssertEqual(try Sched.revisionState(store), revisionsBefore)
        XCTAssertEqual(try Sched.habitFacts(store).icon, "bed")
    }

    // MARK: B54-B58 - profile state

    func testB54TwoPhysicalEnrolledProfilesDeferHistory() async throws {
        let store = try Sched.enrolledStore()
        try Sched.seedProfile(store, trackingStartedAt: Sched.at(day: 0, hour: 9, minute: 7))
        try await assertDeferred(store, .multipleProfiles(count: 2)) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.title = "Still saved"
                $0.priority = .notUrgentAndNotImportant
            }, effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        XCTAssertEqual(try Sched.habitFacts(store).title, "Still saved")
        XCTAssertEqual(try Sched.otherGamificationCounts(store).profiles, 2, "4B never deletes or merges profiles")
    }

    func testB55InvalidProfileTimeZoneDefersHistory() async throws {
        let store = try TxStore.memory()
        try Sched.seedProfile(store, timeZone: "Mars/Olympus_Mons")
        try Sched.seedHabit(store)
        try Sched.seedRevision(store)
        try await assertDeferred(store, .invalidSchedulingTimeZone("Mars/Olympus_Mons")) { repository in
            try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent,
                                                effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        XCTAssertEqual(try Sched.habitFacts(store).priorityRaw, PriorityEisenhower.importantAndUrgent.rawValue)
    }

    func testB56UnsupportedOrMissingProfileCalendarDefersHistory() async throws {
        for calendar in ["iso8601", nil] as [String?] {
            let store = try TxStore.memory()
            try Sched.seedProfile(store, calendar: calendar)
            try Sched.seedHabit(store)
            try Sched.seedRevision(store)
            try await assertDeferred(store, .unsupportedSchedulingCalendar(calendar)) { repository in
                try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.repeating = [.sunday] },
                                                    effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
            }
            XCTAssertEqual(try Sched.habitFacts(store).weekdays, [1])
        }
    }

    func testB57ProfileWithoutTrackingStartAndNoHistoryIsNotEnrolled() async throws {
        let store = try TxStore.memory()
        try Sched.seedProfile(store, trackingStartedAt: nil, timeZone: nil, calendar: nil)
        try Sched.seedHabit(store)
        let ids = Sched.UUIDSequence()
        let profileBefore = try Sched.profileState(store)
        let result = try await Sched.repository(store, ids: ids)
            .updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent, effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(result.scheduleHistory, .notEnrolled)
        XCTAssertEqual(try Sched.habitFacts(store).priorityRaw, PriorityEisenhower.importantAndUrgent.rawValue)
        XCTAssertEqual(try Sched.rows(store, target: nil).count, 0)
        XCTAssertEqual(try Sched.profileState(store), profileBefore)
        XCTAssertEqual(ids.count, 0)
    }

    func testB58ProfileWithoutTrackingStartButWithRevisionRowsReportsOrphanHistory() async throws {
        for withProfile in [true, false] {
            let store = try TxStore.memory()
            if withProfile { try Sched.seedProfile(store, trackingStartedAt: nil) }
            try Sched.seedHabit(store)
            // History of another target is enough to make the store inconsistent.
            try Sched.seedRevision(store, Sched.RevisionSeed(payload: Sched.Payload(target: Sched.otherUUID)))
            try await assertDeferred(store, .orphanRevisionHistory) { repository in
                try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.title = "Saved" },
                                                    effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
            }
            XCTAssertEqual(try Sched.habitFacts(store).title, "Saved")
        }
    }

    // MARK: B59-B62 - open revision multiplicity and chronology

    func testB59EnrolledHabitWithoutOpenRevisionDefersHistory() async throws {
        // No revision at all (the baseline was never written) ...
        let none = try TxStore.memory()
        try Sched.seedProfile(none)
        try Sched.seedHabit(none)
        try await assertDeferred(none, .missingOpenRevision) { repository in
            try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent,
                                                effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        XCTAssertEqual(try Sched.rows(none).count, 0, "4B never fabricates a missing baseline")

        // ... or only a closed one.
        let closedOnly = try Sched.enrolledStore(baseline: Sched.RevisionSeed(to: Sched.at(day: 0, hour: 20)))
        try await assertDeferred(closedOnly, .missingOpenRevision) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.title = "Saved" },
                                                effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
    }

    func testB60TwoConflictingOpenRevisionsDeferHistoryAndStayUntouched() async throws {
        let store = try Sched.enrolledStore()
        try Sched.seedRevision(store, Sched.RevisionSeed(logicalID: Sched.changeID(7), from: Sched.at(day: 0, hour: 12),
                                                          payload: Sched.Payload(mask: 1)))
        try await assertDeferred(store, .multipleOpenRevisions(count: 2)) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.title = "Title and priority"
                $0.priority = .importantAndUrgent
            }, effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        let facts = try Sched.habitFacts(store)
        XCTAssertEqual(facts.title, "Title and priority")
        XCTAssertEqual(facts.priorityRaw, PriorityEisenhower.importantAndUrgent.rawValue)
    }

    func testB61TwoIdenticalPhysicalOpenRevisionsAreStillDeferred() async throws {
        let store = try Sched.enrolledStore()
        try Sched.seedRevision(store) // same logical baseline ID, same payload, second physical row
        XCTAssertEqual(try Sched.rows(store).map(\.payload), [Sched.Payload(), Sched.Payload()])
        try await assertDeferred(store, .multipleOpenRevisions(count: 2)) { repository in
            try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent,
                                                effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
        try await assertDeferred(store, .multipleOpenRevisions(count: 2)) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.title = "Only a title" },
                                                effectiveAt: Sched.at(day: 1, hour: 11)).scheduleHistory
        }
    }

    func testB62MutationEarlierThanTheOpenRevisionDefersHistory() async throws {
        let edit = Sched.at(day: 3, hour: 12)
        let store = try Sched.enrolledStore(baseline: Sched.RevisionSeed(to: edit))
        try Sched.seedRevision(store, Sched.RevisionSeed(logicalID: Sched.changeID(5), from: edit))
        let earlier = Sched.at(day: 2, hour: 12)
        try await assertDeferred(store, .revisionChronologyConflict(latestBoundary: edit, effectiveAt: earlier)) { repository in
            try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent, effectiveAt: earlier).scheduleHistory
        }
        XCTAssertEqual(try Sched.habitFacts(store).priorityRaw, PriorityEisenhower.importantAndUrgent.rawValue)
    }

    func testMutationBeforeTrackingStartedAtDefersHistory() async throws {
        let store = try Sched.enrolledStore()
        let early = Sched.at(day: 0, hour: 8, minute: 59)
        try await assertDeferred(store, .mutationPredatesEnrollment(trackingStartedAt: Sched.trackingStartedAt, effectiveAt: early)) { repository in
            try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.repeating = [.friday] },
                                                effectiveAt: early).scheduleHistory
        }
        XCTAssertEqual(try Sched.habitFacts(store).weekdays, [6])
        XCTAssertEqual(try Sched.otherGamificationCounts(store).profiles, 1)
        let profile = try XCTUnwrap(try ModelContext(store).fetch(FetchDescriptor<GamificationProfileSD>()).first)
        XCTAssertEqual(profile.trackingStartedAt, Sched.trackingStartedAt, "enrollment is never moved")
    }

    // MARK: Stored revision facts 4B cannot trust

    func testOpenRevisionWithAnotherTimeZoneThanTheProfileIsDeferred() async throws {
        let store = try Sched.enrolledStore(baseline: Sched.RevisionSeed(payload: Sched.Payload(timeZone: "Europe/London")))
        try await assertDeferred(store, .currentRevisionDoesNotMatchCurrentHabit) { repository in
            try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent,
                                                effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
        }
    }

    func testOpenRevisionWithAnIncompletePayloadIsDeferred() async throws {
        for payload in [Sched.Payload(priority: nil), Sched.Payload(notification: nil), Sched.Payload(schemaVersion: 2),
                        Sched.Payload(taskType: "weekly")] {
            let store = try Sched.enrolledStore(baseline: Sched.RevisionSeed(payload: payload))
            try await assertDeferred(store, .currentRevisionDoesNotMatchCurrentHabit) { repository in
                try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.title = "Saved" },
                                                    effectiveAt: Sched.at(day: 1, hour: 10)).scheduleHistory
            }
        }
    }

    func testStoreWithoutTheGamificationSchemaIsNotEnrolled() async throws {
        let schema = Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self])
        let legacy = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                                                                         cloudKitDatabase: .none))
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(legacy, ids: ids)
        let created = try await repository.createHabit(id: Sched.targetUUID, metadata: Sched.metadata(), effectiveAt: Sched.at(day: 1, hour: 10))
        let updated = try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent,
                                                          effectiveAt: Sched.at(day: 1, hour: 11))
        let deleted = try await repository.delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 1, hour: 12))
        let restored = try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 1, hour: 13))
        XCTAssertEqual(created.scheduleHistory, .notEnrolled)
        XCTAssertEqual(updated.scheduleHistory, .notEnrolled)
        XCTAssertEqual(deleted, .notEnrolled)
        XCTAssertEqual(restored, .notEnrolled)
        XCTAssertEqual(ids.count, 0)
        XCTAssertEqual(try Sched.habitCount(legacy), 1)
    }

    // MARK: - Helpers

    /// Runs `mutation` and asserts: the typed deferral, revision rows byte-for-byte unchanged, profile
    /// rows unchanged, no revision ID minted, and no occurrence/event/ledger row.
    private func assertDeferred(_ store: ModelContainer, _ conflict: BehaviorScheduleHistoryConflict,
                                file: StaticString = #filePath, line: UInt = #line,
                                _ mutation: (HabitsRepositorySwiftData) async throws -> ScheduleHistoryOutcome) async throws {
        let revisionsBefore = try Sched.revisionState(store)
        let profilesBefore = try Sched.profileState(store)
        let othersBefore = try Sched.otherGamificationCounts(store)
        let ids = Sched.UUIDSequence()
        let outcome = try await mutation(Sched.repository(store, ids: ids))
        XCTAssertEqual(outcome, .revisionDeferred(conflict), file: file, line: line)
        XCTAssertEqual(try Sched.revisionState(store), revisionsBefore, "revision rows must stay untouched", file: file, line: line)
        XCTAssertEqual(try Sched.profileState(store), profilesBefore, file: file, line: line)
        XCTAssertEqual(try Sched.otherGamificationCounts(store), othersBefore, file: file, line: line)
        XCTAssertEqual(ids.count, 0, "a deferred mutation mints no revision ID", file: file, line: line)
    }
}
