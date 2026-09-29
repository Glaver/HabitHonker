import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4B B47-B49, B64-B70: create after enrollment opens a first normal revision, delete closes
/// the open revision, restore opens a new one (never reopening an old one), each in the Habit
/// mutation's single save, and none of them depends on history being healthy.
@MainActor
final class BehaviorScheduleLifecycleTests: XCTestCase {

    // MARK: B47-B49 - create after enrollment

    func testB47NewRepeatingHabitAfterEnrollmentOpensAFirstNormalRevision() async throws {
        let store = try TxStore.memory(); try Sched.seedProfile(store)
        let at = Sched.at(day: 4, hour: 14, minute: 20)
        let result = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .createHabit(id: Sched.targetUUID, metadata: Sched.metadata(), effectiveAt: at)
        XCTAssertEqual(result.scheduleHistory, .revisionApplied(ScheduleRevisionChange(closedRevisionID: nil,
                                                                                        openedRevisionID: Sched.changeID(1),
                                                                                        effectiveAt: at)))
        XCTAssertEqual(try Sched.habitCount(store), 1)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.count, 1)
        let first = try XCTUnwrap(rows.first)
        XCTAssertEqual(first.logicalRevisionID, "rev:v1:123e4567-e89b-12d3-a456-426614174000:change:aaaaaaaa-bbbb-cccc-dddd-000000000001")
        XCTAssertNotEqual(first.logicalRevisionID, Sched.baselineID, "a Habit created after enrollment has no baseline")
        XCTAssertFalse(first.logicalRevisionID.hasSuffix(":baseline"))
        XCTAssertEqual(first.effectiveFrom, at)
        XCTAssertNil(first.effectiveTo)
        XCTAssertEqual(first.payload, Sched.Payload())
    }

    func testB48NewOneTimeHabitAfterEnrollmentOpensAFirstNormalRevision() async throws {
        let store = try TxStore.memory(); try Sched.seedProfile(store)
        let at = Sched.at(day: 4, hour: 14, minute: 20)
        let due = Sched.at(day: 10, hour: 23, minute: 59)
        let result = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .createHabit(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.type = .dueDate
                $0.repeating = [.monday]
                $0.dueDate = due
                $0.isNotificationActivated = false
                $0.priority = .importantAndUrgent
            }, effectiveAt: at)
        XCTAssertEqual(result.scheduleHistory, .revisionApplied(ScheduleRevisionChange(closedRevisionID: nil,
                                                                                        openedRevisionID: Sched.changeID(1),
                                                                                        effectiveAt: at)))
        let first = try XCTUnwrap(try Sched.rows(store).first)
        XCTAssertEqual(first.logicalRevisionID, Sched.changeID(1))
        XCTAssertEqual(first.effectiveFrom, at)
        XCTAssertNil(first.effectiveTo)
        XCTAssertEqual(first.payload, Sched.Payload(taskType: "oneTime", mask: 0, hour: nil, minute: nil, dueAt: due,
                                                    priority: BehaviorPriority.importantAndUrgent.rawValue, notification: false))
    }

    func testB49CreateWritesHabitAndFirstRevisionInOneAtomicSave() async throws {
        let store = try TxStore.memory(); try Sched.seedProfile(store)
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let target = Sched.targetUUID
        await repository.setBeforeCommitForTesting { context in
            // Both halves are staged in the one context when the save is about to run.
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitSD>(predicate: #Predicate<HabitSD> { $0.id == target })), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 1)
            throw Sched.injected
        }
        do {
            _ = try await repository.createHabit(id: target, metadata: Sched.metadata(), effectiveAt: Sched.at(day: 1, hour: 10))
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before, "neither the Habit nor its revision may persist")
        XCTAssertEqual(try Sched.habitCount(store), 0)
    }

    func testCreateWhenHistoryIsUnsafeStillCreatesTheHabit() async throws {
        // The target id already carries an open revision (for example from a synced device).
        let store = try TxStore.memory(); try Sched.seedProfile(store)
        try Sched.seedRevision(store)
        let revisionsBefore = try Sched.revisionState(store)
        let ids = Sched.UUIDSequence()
        let result = try await Sched.repository(store, ids: ids)
            .createHabit(id: Sched.targetUUID, metadata: Sched.metadata(), effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(result.scheduleHistory, .revisionDeferred(.openRevisionAlreadyExists))
        XCTAssertEqual(try Sched.habitCount(store), 1, "creating a Habit never depends on gamification history health")
        XCTAssertEqual(try Sched.revisionState(store), revisionsBefore)
        XCTAssertEqual(ids.count, 0)

        let twoProfiles = try TxStore.memory()
        try Sched.seedProfile(twoProfiles); try Sched.seedProfile(twoProfiles)
        let unsafe = try await Sched.repository(twoProfiles, ids: ids)
            .createHabit(id: Sched.targetUUID, metadata: Sched.metadata(), effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(unsafe.scheduleHistory, .revisionDeferred(.multipleProfiles(count: 2)))
        XCTAssertEqual(try Sched.habitCount(twoProfiles), 1)
        XCTAssertEqual(try Sched.rows(twoProfiles, target: nil).count, 0)
    }

    func testCreateWithAnExistingIDStillThrowsAndWritesNothing() async throws {
        let store = try Sched.enrolledStore()
        let before = try TxStore.state(store)
        do {
            _ = try await Sched.repository(store, ids: Sched.UUIDSequence())
                .createHabit(id: Sched.targetUUID, metadata: Sched.metadata { $0.title = "Impostor" }, effectiveAt: Sched.at(day: 1, hour: 10))
            XCTFail("expected alreadyExists")
        } catch {
            XCTAssertEqual(error as? HabitRepositoryError, .alreadyExists(Sched.targetUUID))
        }
        XCTAssertEqual(try TxStore.state(store), before)
    }

    // MARK: B64-B66 - delete

    func testB64HealthyDeleteClosesTheOpenRevisionAndOpensNone() async throws {
        let store = try Sched.enrolledStore()
        let ids = Sched.UUIDSequence()
        let at = Sched.at(day: 3, hour: 20)
        let outcome = try await Sched.repository(store, ids: ids).delete(id: Sched.targetUUID, effectiveAt: at)
        XCTAssertEqual(outcome, .revisionApplied(ScheduleRevisionChange(closedRevisionID: Sched.baselineID,
                                                                        openedRevisionID: nil, effectiveAt: at)))
        XCTAssertEqual(try Sched.habitCount(store), 0)
        XCTAssertEqual(try Sched.archiveCount(store), 1)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.logicalRevisionID, Sched.baselineID)
        XCTAssertEqual(rows.first?.effectiveFrom, Sched.trackingStartedAt)
        XCTAssertEqual(rows.first?.effectiveTo, at)
        XCTAssertEqual(rows.first?.payload, Sched.Payload())
        XCTAssertEqual(ids.count, 0)
    }

    func testB65DeleteWithDuplicateOpenRevisionsStillDeletes() async throws {
        let store = try Sched.enrolledStore()
        try Sched.seedRevision(store, Sched.RevisionSeed(logicalID: Sched.changeID(3), from: Sched.at(day: 0, hour: 10)))
        let revisionsBefore = try Sched.revisionState(store)
        let outcome = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 3, hour: 20))
        XCTAssertEqual(outcome, .revisionDeferred(.multipleOpenRevisions(count: 2)))
        XCTAssertEqual(try Sched.habitCount(store), 0, "gamification history never prevents deletion")
        XCTAssertEqual(try Sched.archiveCount(store), 1)
        XCTAssertEqual(try Sched.revisionState(store), revisionsBefore)
    }

    func testDeleteWhoseOpenRevisionNoLongerMatchesStillDeletes() async throws {
        let store = try Sched.enrolledStore(habit: Sched.HabitSeed(icon: "bed"))
        let revisionsBefore = try Sched.revisionState(store)
        let outcome = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 3, hour: 20))
        XCTAssertEqual(outcome, .revisionDeferred(.currentRevisionDoesNotMatchCurrentHabit))
        XCTAssertEqual(try Sched.habitCount(store), 0)
        XCTAssertEqual(try Sched.revisionState(store), revisionsBefore)
    }

    func testB66DeleteFailureRollsBackTheLifecycleChangeAndTheRevisionClose() async throws {
        let store = try Sched.enrolledStore()
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let at = Sched.at(day: 3, hour: 20)
        await repository.setBeforeCommitForTesting { context in
            XCTAssertTrue(context.deletedModelsArray.contains { $0 is HabitSD }, "the Habit delete is staged")
            XCTAssertTrue(context.insertedModelsArray.contains { $0 is DeletedHabitSD }, "the archive is staged")
            let revisions = try context.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>())
            XCTAssertEqual(revisions.map(\.effectiveTo), [at], "the revision close is staged")
            throw Sched.injected
        }
        do {
            try await repository.delete(id: Sched.targetUUID, effectiveAt: at)
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before)
        XCTAssertEqual(try Sched.habitCount(store), 1)
        XCTAssertNil(try Sched.rows(store).first?.effectiveTo)
    }

    // MARK: B67-B70 - restore

    func testB67HealthyRestoreOpensANewNormalRevision() async throws {
        let store = try Sched.enrolledStore()
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(store, ids: ids)
        let deletedAt = Sched.at(day: 2, hour: 20)
        let restoredAt = Sched.at(day: 5, hour: 8)
        try await repository.delete(id: Sched.targetUUID, effectiveAt: deletedAt)
        let outcome = try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: restoredAt)
        XCTAssertEqual(outcome, .revisionApplied(ScheduleRevisionChange(closedRevisionID: nil,
                                                                        openedRevisionID: Sched.changeID(1),
                                                                        effectiveAt: restoredAt)))
        XCTAssertEqual(try Sched.habitCount(store), 1)
        XCTAssertEqual(try Sched.archiveCount(store), 0)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.logicalRevisionID), [Sched.baselineID, Sched.changeID(1)])
        XCTAssertEqual(rows.map(\.effectiveFrom), [Sched.trackingStartedAt, restoredAt])
        XCTAssertEqual(rows.map(\.effectiveTo), [deletedAt, nil])
        XCTAssertEqual(rows.map(\.payload), [Sched.Payload(), Sched.Payload()])
    }

    func testB68RestoreNeverReopensAnOldRevision() async throws {
        let store = try Sched.enrolledStore()
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let t1 = Sched.at(day: 1, hour: 20), t2 = Sched.at(day: 2, hour: 8), t3 = Sched.at(day: 3, hour: 20), t4 = Sched.at(day: 3, hour: 20)
        try await repository.delete(id: Sched.targetUUID, effectiveAt: t1)
        try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: t2)
        try await repository.delete(id: Sched.targetUUID, effectiveAt: t3)
        // Restoring at the very instant of the delete is representable: [t2, t3) then [t4 = t3, nil).
        let outcome = try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: t4)
        XCTAssertEqual(outcome, .revisionApplied(ScheduleRevisionChange(closedRevisionID: nil,
                                                                        openedRevisionID: Sched.changeID(2),
                                                                        effectiveAt: t4)))
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.logicalRevisionID), [Sched.baselineID, Sched.changeID(1), Sched.changeID(2)])
        XCTAssertEqual(rows.map(\.effectiveFrom), [Sched.trackingStartedAt, t2, t4])
        XCTAssertEqual(rows.map(\.effectiveTo), [t1, t3, nil])
        XCTAssertEqual(rows.filter { $0.effectiveTo == nil }.count, 1)
    }

    func testB69RestoreWithUnsafeHistoryRestoresWithoutFabricatingARevision() async throws {
        // Two open revisions survive a deferred delete ...
        let store = try Sched.enrolledStore()
        try Sched.seedRevision(store, Sched.RevisionSeed(logicalID: Sched.changeID(3), from: Sched.at(day: 0, hour: 10)))
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(store, ids: ids)
        let deleted = try await repository.delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 2, hour: 20))
        XCTAssertEqual(deleted, .revisionDeferred(.multipleOpenRevisions(count: 2)))
        let revisionsBefore = try Sched.revisionState(store)
        let restored = try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 4, hour: 9))
        XCTAssertEqual(restored, .revisionDeferred(.multipleOpenRevisions(count: 2)))
        XCTAssertEqual(try Sched.habitCount(store), 1)
        XCTAssertEqual(try Sched.revisionState(store), revisionsBefore)
        XCTAssertEqual(ids.count, 0)

        // ... and one open revision left behind by a delete that could not close it.
        let single = try TxStore.memory()
        try Sched.seedProfile(single)
        try Sched.seedArchive(single, deletedAt: Sched.at(day: 2, hour: 20))
        try Sched.seedRevision(single)
        let singleBefore = try Sched.revisionState(single)
        let outcome = try await Sched.repository(single, ids: ids)
            .restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 4, hour: 9))
        XCTAssertEqual(outcome, .revisionDeferred(.openRevisionAlreadyExists))
        XCTAssertEqual(try Sched.habitCount(single), 1)
        XCTAssertEqual(try Sched.revisionState(single), singleBefore)
    }

    func testRestoreOfAHabitArchivedBeforeEnrollmentOpensItsFirstRevision() async throws {
        let store = try TxStore.memory()
        try Sched.seedProfile(store)
        try Sched.seedArchive(store, deletedAt: Sched.at(day: -3, hour: 12))
        let at = Sched.at(day: 2, hour: 9)
        let outcome = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: at)
        XCTAssertEqual(outcome, .revisionApplied(ScheduleRevisionChange(closedRevisionID: nil,
                                                                        openedRevisionID: Sched.changeID(1), effectiveAt: at)))
        XCTAssertEqual(try Sched.rows(store).map(\.payload), [Sched.Payload()])
    }

    func testB70RestoreFailureRollsBackTheRestoreAndTheNewRevision() async throws {
        let store = try Sched.enrolledStore(baseline: Sched.RevisionSeed(to: Sched.at(day: 2, hour: 20)))
        let context = ModelContext(store)
        for habit in try context.fetch(FetchDescriptor<HabitSD>()) { context.delete(habit) }
        try context.save()
        try Sched.seedArchive(store, deletedAt: Sched.at(day: 2, hour: 20))
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        await repository.setBeforeCommitForTesting { context in
            XCTAssertTrue(context.insertedModelsArray.contains { $0 is HabitSD }, "the restored Habit is staged")
            XCTAssertTrue(context.deletedModelsArray.contains { $0 is DeletedHabitSD }, "the archive removal is staged")
            XCTAssertTrue(context.insertedModelsArray.contains { $0 is BehaviorScheduleRevisionSD }, "the new revision is staged")
            throw Sched.injected
        }
        do {
            try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 4, hour: 9))
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before)
        XCTAssertEqual(try Sched.habitCount(store), 0)
        XCTAssertEqual(try Sched.archiveCount(store), 1)
        XCTAssertEqual(try Sched.rows(store).count, 1)
    }
}
