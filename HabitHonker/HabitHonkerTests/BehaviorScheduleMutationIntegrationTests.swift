import Combine
import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4B B71-B81, B84 plus application-boundary wiring: atomic rollback of every staged write
/// set, completion history untouched, profile immutable, no other gamification writes, serialized
/// concurrency, and `effectiveAt` captured from the service's injected clock.
@MainActor
final class BehaviorScheduleMutationIntegrationTests: XCTestCase {

    // MARK: B71-B75 - atomicity (failure after staging, and a real failing save)

    func testB71MetadataCloseAndInsertRollBackTogether() async throws {
        let store = try Sched.enrolledStore()
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let at = Sched.at(day: 1, hour: 10)
        let baselineID = Sched.baselineID
        await repository.setBeforeCommitForTesting { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<HabitSD>()).map(\.title), ["Staged title"])
            let revisions = try context.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>())
            XCTAssertEqual(revisions.count, 2)
            XCTAssertEqual(revisions.filter { $0.logicalRevisionID == baselineID }.map(\.effectiveTo), [at])
            XCTAssertEqual(revisions.filter { $0.logicalRevisionID != baselineID }.map(\.effectiveFrom), [at])
            throw Sched.injected
        }
        let edit = Sched.metadata { $0.title = "Staged title"; $0.priority = .importantAndUrgent }
        do {
            _ = try await repository.updateMetadata(id: Sched.targetUUID, metadata: edit, effectiveAt: at)
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before)
        XCTAssertEqual(try Sched.habitFacts(store).title, "Gym", "old metadata remains")
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.count, 1, "the new revision is absent")
        XCTAssertNil(rows.first?.effectiveTo, "the old revision is still open")

        // Nothing was left behind: the same mutation succeeds once the failure is gone.
        await repository.setBeforeCommitForTesting(nil)
        let retry = try await repository.updateMetadata(id: Sched.targetUUID, metadata: edit, effectiveAt: at)
        guard case .revisionApplied = retry.scheduleHistory else { return XCTFail("\(retry.scheduleHistory)") }
    }

    func testB71bActualFailingSaveOfAnEditLeavesNoPartialState() async throws {
        try await withReadOnlyEnrolledStore { store in
            _ = try await Sched.repository(store, ids: Sched.UUIDSequence())
                .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.repeating = [.sunday] },
                                effectiveAt: Sched.at(day: 1, hour: 10))
        }
    }

    func testB72PriorityAndRevisionRollBackTogether() async throws {
        let store = try Sched.enrolledStore()
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        await repository.setBeforeCommitForTesting { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<HabitSD>()).map(\.priorityRaw), [PriorityEisenhower.importantAndUrgent.rawValue])
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 2)
            throw Sched.injected
        }
        do {
            _ = try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent, effectiveAt: Sched.at(day: 1, hour: 10))
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before)
        XCTAssertEqual(try Sched.habitFacts(store).priorityRaw, PriorityEisenhower.importantButNotUrgent.rawValue)
    }

    func testB73OneTimeCreateAndInitialRevisionRollBackTogether() async throws {
        let store = try TxStore.memory(); try Sched.seedProfile(store)
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        await repository.setBeforeCommitForTesting { context in
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitSD>()), 1)
            XCTAssertEqual(try context.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>()).map(\.taskTypeRawValue), ["oneTime"])
            throw Sched.injected
        }
        do {
            _ = try await repository.createHabit(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.type = .dueDate
                $0.dueDate = Sched.at(day: 6, hour: 12)
            }, effectiveAt: Sched.at(day: 1, hour: 10))
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before)
    }

    func testB74ActualFailingSaveOfADeleteLeavesNoPartialState() async throws {
        try await withReadOnlyEnrolledStore { store in
            _ = try await Sched.repository(store, ids: Sched.UUIDSequence())
                .delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 3, hour: 20))
        }
    }

    func testB75ActualFailingSaveOfARestoreLeavesNoPartialState() async throws {
        try await withReadOnlyEnrolledStore(archived: true) { store in
            _ = try await Sched.repository(store, ids: Sched.UUIDSequence())
                .restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 4, hour: 9))
        }
    }

    // MARK: B76-B79 - completion history is never touched by schedule history

    func testB76RevisionRelevantEditKeepsRecordIDsDatesCountsAndRows() async throws {
        let store = try Sched.enrolledStore(habit: Sched.HabitSeed(records: Self.records))
        let factsBefore = try Sched.recordFacts(store)
        XCTAssertEqual(factsBefore.count, 3)
        let result = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata {
                $0.repeating = [.tuesday, .thursday, .saturday]
                $0.dueDate = Sched.at(day: 0, hour: 6)
                $0.icon = "bed"
            }, effectiveAt: Sched.at(day: 1, hour: 10))
        guard case .revisionApplied = result.scheduleHistory else { return XCTFail("\(result.scheduleHistory)") }
        XCTAssertEqual(try Sched.recordFacts(store), factsBefore)
        XCTAssertEqual(try Sched.recordRowCount(store), 3)
        XCTAssertEqual(Set(result.habit.record.map { Sched.RecordFact(id: $0.id, date: $0.date, count: $0.count) }), factsBefore)
    }

    func testB77PriorityRevisionKeepsCompletionRecords() async throws {
        let store = try Sched.enrolledStore(habit: Sched.HabitSeed(records: Self.records))
        let factsBefore = try Sched.recordFacts(store)
        let result = try await Sched.repository(store, ids: Sched.UUIDSequence())
            .updatePriority(id: Sched.targetUUID, priority: .notUrgentAndNotImportant, effectiveAt: Sched.at(day: 1, hour: 10))
        guard case .revisionApplied = result.scheduleHistory else { return XCTFail("\(result.scheduleHistory)") }
        XCTAssertEqual(try Sched.recordFacts(store), factsBefore)
        XCTAssertEqual(try Sched.recordRowCount(store), 3)
    }

    func testB78DeleteRestoreRevisionLifecyclePreservesArchiveRecordSemantics() async throws {
        let enrolled = try Sched.enrolledStore(habit: Sched.HabitSeed(records: Self.records))
        let legacy = try TxStore.memory(); try Sched.seedHabit(legacy, Sched.HabitSeed(records: Self.records))
        let original = try Sched.recordFacts(enrolled)
        var rowCounts: [Int] = []
        for store in [enrolled, legacy] {
            let repository = Sched.repository(store, ids: Sched.UUIDSequence())
            try await repository.delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 2, hour: 20))
            try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 4, hour: 9))
            XCTAssertEqual(try Sched.recordFacts(store), original, "restored records keep their ids, dates and counts")
            rowCounts.append(try Sched.recordRowCount(store))
        }
        XCTAssertEqual(rowCounts[0], rowCounts[1], "schedule history adds, removes and copies no record row")
        let revisions = try Sched.rows(enrolled)
        XCTAssertEqual(revisions.map(\.logicalRevisionID), [Sched.baselineID, Sched.changeID(1)])
        XCTAssertEqual(revisions.map(\.effectiveTo), [Sched.at(day: 2, hour: 20), nil])
        XCTAssertEqual(try Sched.rows(legacy, target: nil).count, 0)
    }

    func testB79StaleDetailsSaveAfterEnrollmentKeepsTheCompletion() async throws {
        let store = try TxStore.memory(); try Sched.seedProfile(store)
        let clock = ScheduleTestClock(Sched.at(day: 1, hour: 9))
        let service = makeService(store, clock: clock)
        let created = try await service.createHabit(Self.habitModel())
        let loaded = try await service.fetchHabit(id: created.id)
        var draft = try XCTUnwrap(loaded)
        clock.now = Sched.at(day: 1, hour: 12)
        _ = try await service.completeHabit(id: created.id)
        draft.title = "Gym (evening)"
        clock.now = Sched.at(day: 1, hour: 13)
        let saved = try await service.updateHabit(draft)
        XCTAssertEqual(saved.title, "Gym (evening)")
        XCTAssertEqual(saved.record.reduce(0) { $0 + $1.count }, 1, "the stale draft must not erase the completion")
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.count, 1, "a title-only save adds no revision")
        XCTAssertEqual(rows.first?.effectiveFrom, Sched.at(day: 1, hour: 9))
        XCTAssertNil(rows.first?.effectiveTo)
    }

    func testLegacyCompletionHasNoScheduleHistoryEffect() async throws {
        let store = try Sched.enrolledStore()
        let revisionsBefore = try Sched.revisionState(store)
        let service = makeService(store, clock: ScheduleTestClock(Sched.at(day: 1, hour: 12)))
        let completed = try await service.completeHabit(id: Sched.targetUUID)
        XCTAssertEqual(completed?.record.reduce(0) { $0 + $1.count }, 1)
        XCTAssertEqual(try Sched.revisionState(store), revisionsBefore)
        XCTAssertEqual(try Sched.otherGamificationCounts(store),
                       Sched.OtherGamificationCounts(occurrences: 0, events: 0, ledger: 0, profiles: 1))
    }

    // MARK: B80-B81 - profile immutability, no profile creation, no other gamification writes

    func testB80ScheduleHistoryNeverChangesTheProfileOrWritesOtherGamificationRows() async throws {
        let store = try TxStore.memory()
        try Sched.seedProfile(store, totalXP: 180, honkerCoins: 12, lifetimeCoinsEarned: 20, lifetimeCoinsSpent: 8)
        try Sched.seedHabit(store)
        try Sched.seedRevision(store)
        let profileBefore = try Sched.profileState(store)
        try await runEveryMutation(store)
        XCTAssertEqual(try Sched.profileState(store), profileBefore,
                       "trackingStartedAt, time zone, calendar, XP and every coin counter stay exactly as stored")
        XCTAssertEqual(try Sched.otherGamificationCounts(store),
                       Sched.OtherGamificationCounts(occurrences: 0, events: 0, ledger: 0, profiles: 1))
        XCTAssertGreaterThan(try Sched.rows(store, target: nil).count, 1, "history was written in this run")
    }

    func testB81ScheduleHistoryNeverCreatesAProfile() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        try await runEveryMutation(store)
        try Phase2TestStore.assertNewTablesEmpty(ModelContext(store))
    }

    // MARK: B84 - concurrency through the real service/repository boundary

    func testB84ConcurrentCompletionsAndRevisionEditsKeepCountsAndAValidChain() async throws {
        let store = try Sched.enrolledStore()
        let actor = Sched.repository(store, ids: Sched.UUIDSequence())
        let repository = SwiftDataHabitRepository(repository: actor)
        let clock = ScheduleTestClock(Sched.at(day: 1, hour: 12))
        // Two services (list and priority matrix) share the one repository actor, as in production.
        let listService = HabitService(repository: repository, habitEvents: ScheduleSilentEvents(),
                                       now: { clock.now }, calendar: { scheduleLACalendar() })
        let matrixService = HabitService(repository: repository, habitEvents: ScheduleSilentEvents(),
                                         now: { clock.now }, calendar: { scheduleLACalendar() })
        let loaded = try await listService.fetchHabit(id: Sched.targetUUID)
        var staleDraft = try XCTUnwrap(loaded)
        let priorities: [PriorityEisenhower] = [.importantAndUrgent, .urgentButNotImportant,
                                                .importantButNotUrgent, .notUrgentAndNotImportant]
        var tasks: [Task<Void, Error>] = []
        for index in 0..<20 {
            tasks.append(Task { _ = try await listService.completeHabit(id: Sched.targetUUID) })
            tasks.append(Task { _ = try await matrixService.changePriority(id: Sched.targetUUID, to: priorities[index % 4]) })
            if index % 2 == 0 {
                staleDraft.title = "Edit \(index)"
                staleDraft.repeating = index % 4 == 0 ? [.monday] : [.monday, .wednesday, .friday]
                let draft = staleDraft
                tasks.append(Task { _ = try await listService.updateHabit(draft) })
            }
        }
        for task in tasks { try await task.value }

        let storedValue = try await listService.fetchHabit(id: Sched.targetUUID)
        let stored = try XCTUnwrap(storedValue)
        XCTAssertEqual(stored.record.reduce(0) { $0 + $1.count }, 20, "no completion may be lost")
        XCTAssertEqual(try Sched.recordRowCount(store), 1)

        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.filter { $0.effectiveTo == nil }.count, 1, "exactly one open revision")
        XCTAssertEqual(Set(rows.map(\.logicalRevisionID)).count, rows.count, "logical revision IDs are unique")
        XCTAssertEqual(rows.first?.logicalRevisionID, Sched.baselineID)
        XCTAssertTrue(rows.dropFirst().allSatisfy { $0.logicalRevisionID.contains(":change:") })
        XCTAssertTrue(rows.filter { $0.effectiveTo != nil }.allSatisfy { $0.effectiveTo == clock.now })
        // The open revision describes the Habit exactly as it was finally committed.
        let openRow = try XCTUnwrap(rows.first { $0.effectiveTo == nil })
        let facts = try Sched.habitFacts(store)
        XCTAssertEqual(openRow.payload.priority, facts.priorityRaw)
        XCTAssertEqual(openRow.payload.mask, facts.weekdays.reduce(0) { $0 | (1 << ($1 - 1)) })
        XCTAssertEqual(openRow.payload.hour, 7)
        XCTAssertEqual(openRow.payload.minute, 30)
    }

    // MARK: Application boundary wiring

    func testServiceCapturesEffectiveAtFromItsInjectedClock() async throws {
        let store = try Sched.enrolledStore()
        let clock = ScheduleTestClock(Sched.at(day: 1, hour: 10))
        let service = HabitService(repository: SwiftDataHabitRepository(repository: Sched.repository(store, ids: Sched.UUIDSequence())),
                                   habitEvents: ScheduleSilentEvents(), now: { clock.now }, calendar: { scheduleLACalendar() })
        let t1 = clock.now
        _ = try await service.changePriority(id: Sched.targetUUID, to: .importantAndUrgent)
        clock.now = Sched.at(day: 2, hour: 11)
        let loaded = try await service.fetchHabit(id: Sched.targetUUID)
        var draft = try XCTUnwrap(loaded)
        draft.icon = "bed"
        _ = try await service.updateHabit(draft)
        clock.now = Sched.at(day: 3, hour: 12)
        try await service.deleteHabit(id: Sched.targetUUID)
        clock.now = Sched.at(day: 4, hour: 13)
        try await service.restoreDeletedHabit(id: Sched.targetUUID)
        clock.now = Sched.at(day: 5, hour: 14)
        _ = try await service.createHabit(Self.habitModel(id: Sched.otherUUID))

        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.effectiveFrom), [Sched.trackingStartedAt, t1, Sched.at(day: 2, hour: 11), Sched.at(day: 4, hour: 13)])
        XCTAssertEqual(rows.map(\.effectiveTo), [t1, Sched.at(day: 2, hour: 11), Sched.at(day: 3, hour: 12), nil])
        XCTAssertEqual(try Sched.rows(store, target: Sched.otherUUID).map(\.effectiveFrom), [Sched.at(day: 5, hour: 14)])
    }

    func testAppDependenciesWireThePlannerAndTheV1RevisionIDProvider() async throws {
        let store = try TxStore.memory()
        // Enrolled in the past, so the real wall clock of the default service is after enrollment.
        let past = Date(timeIntervalSince1970: 1_600_000_000)
        try Sched.seedProfile(store, trackingStartedAt: past)
        try Sched.seedHabit(store)
        try Sched.seedRevision(store, Sched.RevisionSeed(from: past))
        let dependencies = AppDependencies.make(container: store, storageDurability: .durableLocal)
        _ = try await dependencies.habitService.changePriority(id: Sched.targetUUID, to: .importantAndUrgent)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.count, 2)
        let next = try XCTUnwrap(rows.first { $0.effectiveTo == nil })
        let prefix = "rev:v1:\(Sched.targetText):change:"
        XCTAssertTrue(next.logicalRevisionID.hasPrefix(prefix), next.logicalRevisionID)
        let suffix = String(next.logicalRevisionID.dropFirst(prefix.count))
        XCTAssertEqual(UUID(uuidString: suffix)?.uuidString.lowercased(), suffix)
        XCTAssertEqual(next.payload.priority, BehaviorPriority.importantAndUrgent.rawValue)
    }

    // MARK: - Helpers

    private static let records: [(UUID, Date, Int)] = [
        (UUID(uuidString: "4B4B4B4B-0000-0000-0000-000000000011")!, Sched.at(day: -2, hour: 8), 1),
        (UUID(uuidString: "4B4B4B4B-0000-0000-0000-000000000012")!, Sched.at(day: -1, hour: 19), 3),
        (UUID(uuidString: "4B4B4B4B-0000-0000-0000-000000000013")!, Sched.at(day: 0, hour: 7, minute: 45), 2)
    ]

    private static func habitModel(id: UUID = Sched.targetUUID) -> HabitModel {
        HabitModel(id: id, icon: "atom", iconColor: .red, title: "Gym", description: "Legs", tags: ["health"],
                   priority: .importantButNotUrgent, type: .repeating, repeating: [.monday, .wednesday, .friday],
                   dueDate: Sched.reminder, notificationActivated: true)
    }

    private func makeService(_ store: ModelContainer, clock: ScheduleTestClock) -> HabitService {
        HabitService(repository: SwiftDataHabitRepository(repository: Sched.repository(store, ids: Sched.UUIDSequence())),
                     habitEvents: ScheduleSilentEvents(), now: { clock.now }, calendar: { scheduleLACalendar() })
    }

    /// Create, relevant edit, priority, title-only edit, delete and restore, through the actor.
    private func runEveryMutation(_ store: ModelContainer) async throws {
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        _ = try await repository.createHabit(id: Sched.otherUUID, metadata: Sched.metadata(), effectiveAt: Sched.at(day: 1, hour: 9))
        _ = try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.repeating = [.sunday] },
                                                effectiveAt: Sched.at(day: 1, hour: 10))
        _ = try await repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent, effectiveAt: Sched.at(day: 1, hour: 11))
        _ = try await repository.updateMetadata(id: Sched.targetUUID,
                                                metadata: Sched.metadata { $0.repeating = [.sunday]; $0.priority = .importantAndUrgent; $0.title = "T" },
                                                effectiveAt: Sched.at(day: 1, hour: 12))
        try await repository.delete(id: Sched.targetUUID, effectiveAt: Sched.at(day: 2, hour: 10))
        try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 3, hour: 10))
    }

    /// Seeds an enrolled on-disk store (optionally with the Habit already archived and its baseline
    /// closed), reopens it read-only, and asserts that `mutation` fails at save and changes nothing.
    private func withReadOnlyEnrolledStore(archived: Bool = false,
                                           file: StaticString = #filePath, line: UInt = #line,
                                           _ mutation: (ModelContainer) async throws -> Void) async throws {
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("readonly-schedule.store")
        try autoreleasepool {
            let writable = try TxStore.disk(url)
            try Sched.seedProfile(writable)
            if archived {
                try Sched.seedArchive(writable, deletedAt: Sched.at(day: 2, hour: 20))
                try Sched.seedRevision(writable, Sched.RevisionSeed(to: Sched.at(day: 2, hour: 20)))
            } else {
                try Sched.seedHabit(writable)
                try Sched.seedRevision(writable)
            }
        }
        let store = try TxStore.disk(url, allowsSave: false)
        let before = try TxStore.state(store)
        do {
            try await mutation(store)
            XCTFail("a read-only store's save must fail", file: file, line: line)
        } catch {
            XCTAssertFalse(error is Sched.InjectedFailure, file: file, line: line)
        }
        XCTAssertEqual(try TxStore.state(store), before, "no partial Habit or revision state may persist", file: file, line: line)
    }
}

/// Legacy completion day policy for these tests: Gregorian, Los Angeles. A plain function, so the
/// service's clock/calendar closures capture no test-class state.
private func scheduleLACalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: Sched.la)!
    return calendar
}
