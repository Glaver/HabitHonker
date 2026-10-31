import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4E E35–E47, E71–E82 and E86–E89:
/// - existing data survives enrollment untouched;
/// - legacy history produces no gamification;
/// - enrollment switches on the Phase 4B writer for the real Habit mutation paths;
/// - live completion stays on the legacy path;
/// - `AppDependencies` exposes a container-scoped enrollment service that never runs by itself.
@MainActor
final class GamificationEnrollmentIntegrationTests: XCTestCase {

    // MARK: E35–E41, §53 — existing data is unchanged

    func testE35To41EnrollmentLeavesEveryExistingRowUnchanged() async throws {
        let store = try TxStore.memory()
        try seedLegacyWorld(store)
        let context = ModelContext(store)
        let legacyBefore = try Phase2TestStore.legacySnapshot(context)
        let recordsBefore = try Sched.recordRowCount(store)
        let habitA = try Sched.recordFacts(store, habitID: Enroll.uuid(1))
        let habitC = try Sched.recordFacts(store, habitID: Enroll.uuid(3))
        XCTAssertEqual(habitA.count, 200)

        let result = try await Enroll.service(store).enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 3)))

        // Habits, archives, records and presets: every field of every row is identical (E35–E41).
        XCTAssertEqual(try Phase2TestStore.legacySnapshot(ModelContext(store)), legacyBefore)
        XCTAssertEqual(try Sched.recordRowCount(store), recordsBefore, "E36")
        XCTAssertEqual(try Sched.recordFacts(store, habitID: Enroll.uuid(1)), habitA, "E37/E38: ids, dates and counts")
        XCTAssertEqual(try Sched.recordFacts(store, habitID: Enroll.uuid(2)), [])
        XCTAssertEqual(try Sched.recordFacts(store, habitID: Enroll.uuid(3)), habitC)
        // The only new rows are the profile and the baselines.
        let after = try TxStore.state(store)
        let added = Set(after.keys).subtracting(legacyBefore.keys)
        XCTAssertEqual(added.filter { $0.hasPrefix("GamificationProfileSD:") }.count, 1)
        XCTAssertEqual(added.filter { $0.hasPrefix("BehaviorScheduleRevisionSD:") }.count, 3)
        XCTAssertEqual(added.count, 4)
    }

    // MARK: E42–E47, §53–§54 — no retroactive gamification

    func testE42To47LegacyHistoryProducesNoGamification() async throws {
        let store = try TxStore.memory()
        try seedLegacyWorld(store)
        _ = try await Enroll.service(store).enroll(Enroll.request())
        try Enroll.assertNoRewardRows(store) // E42–E44
        let profile = try Enroll.onlyProfile(store)
        XCTAssertEqual(profile.totalXP, 0, "E45")
        XCTAssertEqual([profile.honkerCoins, profile.lifetimeCoinsEarned, profile.lifetimeCoinsSpent], [0, 0, 0], "E46")
        // E47: the enrollment graph has no reward dependency to invoke (see the architecture guards);
        // the ledger, the reward authority, is empty.
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 0)
    }

    func testSameDayCompletionBeforeEnrollmentStaysLegacyHistoryOnly() async throws {
        let store = try TxStore.memory()
        let morning = Sched.at(day: 0, hour: 10)
        try Sched.seedHabit(store, Sched.HabitSeed(records: [(Enroll.uuid(900), morning, 1)]))
        _ = try await Enroll.service(store).enroll(Enroll.request(at: Sched.at(day: 0, hour: 15)))
        XCTAssertEqual(try Sched.recordFacts(store), [Sched.RecordFact(id: Enroll.uuid(900), date: morning, count: 1)])
        try Enroll.assertNoRewardRows(store)
        XCTAssertEqual(try Sched.rows(store).map(\.effectiveFrom), [Sched.at(day: 0, hour: 15)],
                       "the baseline starts at enrollment, not at the earlier completion")
    }

    // MARK: E71–E75 — enrollment activates the Phase 4B writer

    func testE71To73EnrollmentActivatesTheRevisionWriterForPriorityChanges() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let world = World(store, now: Sched.at(day: -1, hour: 12))

        // E71: before enrollment the writer reports notEnrolled and writes nothing.
        let early = try await world.repository.updatePriority(id: Sched.targetUUID, priority: .importantAndUrgent,
                                                              effectiveAt: Sched.at(day: -1, hour: 12))
        XCTAssertEqual(early.scheduleHistory, .notEnrolled)
        _ = try await world.service.changePriority(id: Sched.targetUUID, to: .importantButNotUrgent)
        XCTAssertEqual(try Enroll.allRows(store), [])
        XCTAssertEqual(world.ids.count, 0, "no revision ID minted before enrollment")

        // E72: enrollment writes the baseline.
        _ = try await world.enrollment.enroll(Enroll.request())
        let baseline = try Sched.row(try Sched.rows(store), Sched.baselineID)
        XCTAssertEqual(baseline.payload, Sched.Payload())
        XCTAssertNil(baseline.effectiveTo)

        // E73: the real production path now closes the baseline and opens a normal revision.
        let change = Sched.at(day: 1, hour: 10)
        world.clock.now = change
        _ = try await world.service.changePriority(id: Sched.targetUUID, to: .importantAndUrgent)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.logicalRevisionID), [Sched.baselineID, Sched.changeID(1)])
        XCTAssertEqual(try Sched.row(rows, Sched.baselineID).effectiveTo, change)
        let normal = try Sched.row(rows, Sched.changeID(1))
        XCTAssertEqual(normal.effectiveFrom, change)
        XCTAssertNil(normal.effectiveTo)
        XCTAssertEqual(normal.payload.priority, BehaviorPriority.importantAndUrgent.rawValue)

        // The actor reports revisionApplied for the next real change.
        let next = try await world.repository.updatePriority(id: Sched.targetUUID, priority: .notUrgentAndNotImportant,
                                                             effectiveAt: Sched.at(day: 2, hour: 10))
        XCTAssertEqual(next.scheduleHistory, .revisionApplied(ScheduleRevisionChange(
            closedRevisionID: Sched.changeID(1), openedRevisionID: Sched.changeID(2), effectiveAt: Sched.at(day: 2, hour: 10))))
    }

    func testE74E75TitleOnlyEditWritesNothingAndScheduleEditOpensANormalRevision() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let world = World(store, now: Sched.at(day: 1, hour: 10))
        _ = try await world.enrollment.enroll(Enroll.request())
        let loaded = try await world.service.fetchHabit(id: Sched.targetUUID)
        var habit = try XCTUnwrap(loaded)

        habit.title = "Gym (renamed)"
        habit.description = "New description"
        habit.tags = ["other"]
        habit.iconColor = .blue
        _ = try await world.service.updateHabit(habit)
        XCTAssertEqual(try Sched.rows(store).map(\.logicalRevisionID), [Sched.baselineID], "E74")
        XCTAssertNil(try Sched.rows(store).first?.effectiveTo)

        world.clock.now = Sched.at(day: 2, hour: 10)
        habit.repeating = [.tuesday, .thursday]
        _ = try await world.service.updateHabit(habit)
        let rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.logicalRevisionID), [Sched.baselineID, Sched.changeID(1)], "E75")
        XCTAssertEqual(try Sched.row(rows, Sched.baselineID).effectiveTo, Sched.at(day: 2, hour: 10))
        XCTAssertEqual(try Sched.row(rows, Sched.changeID(1)).payload.mask, 4 | 16)
    }

    // MARK: E76–E78, §67 — Habits created after enrollment get a normal revision

    func testE76To78HabitCreatedAfterEnrollmentGetsANormalRevisionNotABaseline() async throws {
        let store = try TxStore.memory() // §67: zero Habits is a valid enrollment
        let world = World(store, now: Sched.at(day: 1, hour: 14, minute: 20))
        let result = try await world.enrollment.enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 0)))

        let created = try await world.service.createHabit(
            HabitModel(id: Sched.otherUUID, icon: "atom", iconColor: .red, title: "New", description: "",
                       priority: .importantAndUrgent, type: .repeating, repeating: [.monday],
                       dueDate: Sched.reminder, notificationActivated: true))
        XCTAssertEqual(created.id, Sched.otherUUID)
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, 1, "E76: one normal revision, no baseline")
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.logicalRevisionID, "rev:v1:\(Sched.otherText):change:aaaaaaaa-bbbb-cccc-dddd-000000000001", "E77")
        XCTAssertFalse(row.logicalRevisionID.hasSuffix(":baseline"))
        XCTAssertEqual(row.effectiveFrom, Sched.at(day: 1, hour: 14, minute: 20), "E78: the creation instant")
        XCTAssertNil(row.effectiveTo)
    }

    // MARK: E79–E82 — delete and restore after enrollment

    func testE79To82DeleteClosesTheBaselineAndRestoreOpensANormalRevision() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let world = World(store, now: Sched.at(day: 2, hour: 20))
        _ = try await world.enrollment.enroll(Enroll.request())

        try await world.service.deleteHabit(id: Sched.targetUUID)
        var rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.logicalRevisionID), [Sched.baselineID], "E80: no replacement revision")
        XCTAssertEqual(rows.first?.effectiveTo, Sched.at(day: 2, hour: 20), "E79")

        world.clock.now = Sched.at(day: 4, hour: 8)
        try await world.service.restoreDeletedHabit(id: Sched.targetUUID)
        rows = try Sched.rows(store)
        XCTAssertEqual(rows.map(\.logicalRevisionID), [Sched.baselineID, Sched.changeID(1)], "E81")
        XCTAssertEqual(try Sched.row(rows, Sched.baselineID).effectiveTo, Sched.at(day: 2, hour: 20), "E82: stays closed")
        let reopened = try Sched.row(rows, Sched.changeID(1))
        XCTAssertEqual(reopened.effectiveFrom, Sched.at(day: 4, hour: 8))
        XCTAssertNil(reopened.effectiveTo)
        XCTAssertEqual(reopened.payload, Sched.Payload(), "the restored definition")
    }

    // MARK: §75–§76 — no live completion cutover

    func testCompletionAfterEnrollmentStaysOnTheLegacyPath() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let world = World(store, now: Sched.at(day: 1, hour: 8))
        _ = try await world.enrollment.enroll(Enroll.request())
        let gamificationBefore = try Sched.profileState(store).merging(try Sched.revisionState(store)) { lhs, _ in lhs }

        let completed = try await world.service.completeHabit(id: Sched.targetUUID)
        XCTAssertEqual(completed?.record.map(\.count), [1])
        XCTAssertEqual(try Sched.recordRowCount(store), 1)
        try Enroll.assertNoRewardRows(store)
        XCTAssertEqual(try Sched.profileState(store).merging(try Sched.revisionState(store)) { lhs, _ in lhs },
                       gamificationBefore, "profile and revisions are untouched by a completion")
    }

    // MARK: E86–E89 — AppDependencies

    func testE86To88AppDependenciesExposeEnrollmentWithoutRunningIt() async throws {
        for state in StorageDurabilityState.allCases {
            let store = try TxStore.memory()
            try Enroll.seedRepresentative(store)
            let dependencies = AppDependencies.make(container: store, storageDurability: state)
            XCTAssertEqual(try Enroll.profiles(store), [], "E86: \(state)")
            XCTAssertEqual(try Enroll.allRows(store), [], "E87: \(state)")
            try Enroll.assertNoRewardRows(store)
            _ = try await dependencies.habitService.fetchHabits()
            XCTAssertEqual(try Enroll.profiles(store), [], "using the graph does not enroll either")

            // E88: the service is exposed through its protocol and gated by this graph's durability.
            let service: any GamificationEnrollmentServicing = dependencies.gamificationEnrollmentService
            if state.supportsDurableGamification {
                let result = try await service.enroll(Enroll.request(at: Sched.at(day: -300, hour: 9)))
                XCTAssertEqual(try Enroll.enrolled(result).baselineRevisionCount, Enroll.representative.count)
            } else {
                try await Enroll.assertRefused(.storageNotDurable(state), store: store) {
                    try await service.enroll(Enroll.request())
                }
            }
        }
    }

    /// The production graph end to end, with the real clock and real revision UUIDs: enroll in the
    /// past, then create a Habit through the graph's `HabitService`.
    func testProductionGraphEnrollmentActivatesRevisionHistoryForItsHabitService() async throws {
        let store = try TxStore.memory()
        let dependencies = AppDependencies.make(container: store, storageDurability: .durableLocal)
        let enrolledAt = Sched.at(day: -300, hour: 9) // 2026-03-17, before the wall clock
        _ = try await dependencies.gamificationEnrollmentService.enroll(Enroll.request(at: enrolledAt))
        let created = try await dependencies.habitService.createHabit(
            HabitModel(icon: "atom", iconColor: .red, title: "Graph", description: "", priority: .importantAndUrgent,
                       type: .repeating, repeating: [.monday], dueDate: Sched.reminder))
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        let prefix = "rev:v1:\(created.id.uuidString.lowercased()):change:"
        XCTAssertTrue(row.logicalRevisionID.hasPrefix(prefix), row.logicalRevisionID)
        XCTAssertNotNil(UUID(uuidString: String(row.logicalRevisionID.dropFirst(prefix.count))))
        XCTAssertGreaterThan(row.effectiveFrom, enrolledAt)
    }

    func testE89EachContainerGetsItsOwnEnrollmentService() async throws {
        let first = try TxStore.memory()
        let second = try TxStore.memory()
        try Sched.seedHabit(first)
        try Sched.seedHabit(second, Sched.HabitSeed(id: Sched.otherUUID))
        let a = AppDependencies.make(container: first, storageDurability: .durableLocal)
        let b = AppDependencies.make(container: second, storageDurability: .durableCloud)

        let secondBefore = try TxStore.state(second)
        _ = try await a.gamificationEnrollmentService.enroll(Enroll.request())
        XCTAssertEqual(try TxStore.state(second), secondBefore, "enrolling store A never reaches store B")
        XCTAssertEqual(try Enroll.allRows(first).map(\.logicalRevisionID), [Sched.baselineID])

        // Store B is its own progression world with its own profile:v1:default.
        let resultB = try await b.gamificationEnrollmentService.enroll(Enroll.request(zone: "Asia/Tokyo"))
        XCTAssertEqual(resultB, .enrolled(Enroll.summary(zone: "Asia/Tokyo", baselines: 1)))
        XCTAssertEqual(try Enroll.onlyProfile(first).schedulingTimeZoneIdentifier, Sched.la)
        XCTAssertEqual(try Enroll.onlyProfile(second).schedulingTimeZoneIdentifier, "Asia/Tokyo")
        XCTAssertEqual(try Enroll.allRows(second).map(\.logicalRevisionID), [Enroll.baselineID(Sched.otherUUID)])

        // Rebuilding a graph for a new store never reaches the old one.
        let third = try TxStore.memory()
        let firstBefore = try TxStore.state(first)
        let rebuilt = AppDependencies.make(container: third, storageDurability: .durableLocal)
        let resultC = try await rebuilt.gamificationEnrollmentService.enroll(Enroll.request())
        XCTAssertEqual(resultC, .enrolled(Enroll.summary(baselines: 0)))
        XCTAssertEqual(try TxStore.state(first), firstBefore)
    }

    // MARK: - Helpers

    /// A HabitService and an enrollment service sharing one repository actor, as `AppDependencies`
    /// wires them, with an injected clock and deterministic revision IDs.
    private struct World {
        let ids = Sched.UUIDSequence()
        let clock: ScheduleTestClock
        let repository: HabitsRepositorySwiftData
        let service: HabitService
        let enrollment: GamificationEnrollmentService

        @MainActor
        init(_ store: ModelContainer, now: Date) {
            let clock = ScheduleTestClock(now)
            let repository = Sched.repository(store, ids: ids)
            self.clock = clock
            self.repository = repository
            self.service = HabitService(repository: SwiftDataHabitRepository(repository: repository),
                                        habitEvents: ScheduleSilentEvents(),
                                        now: { clock.now }, calendar: { enrollmentLACalendar() })
            self.enrollment = Enroll.service(repository)
        }
    }

    /// §53 world: Habit A with 200 old completions, B with none, C completed earlier today; two
    /// archived Habits with their own records; one statistics preset.
    private func seedLegacyWorld(_ store: ModelContainer) throws {
        let oldRecords = (0..<200).map { day in
            (Enroll.uuid(1_000 + day), Sched.at(day: -200 + day, hour: 7), day % 3 + 1)
        }
        try Sched.seedHabit(store, Sched.HabitSeed(id: Enroll.uuid(1), title: "A", records: oldRecords))
        try Sched.seedHabit(store, Sched.HabitSeed(id: Enroll.uuid(2), title: "B"))
        try Sched.seedHabit(store, Sched.HabitSeed(id: Enroll.uuid(3), title: "C", type: .dueDate, weekdays: [],
                                                   dueDate: Sched.at(day: 0, hour: 18),
                                                   records: [(Enroll.uuid(2_000), Sched.at(day: 0, hour: 7), 1)]))
        let context = ModelContext(store)
        for (index, id) in [Enroll.uuid(4), Enroll.uuid(5)].enumerated() {
            let archive = DeletedHabitSD(id: id, icon: "bed", iconColorHex: "#000000FF", title: "Archived \(index)",
                                         descriptionText: "", tags: [], priorityRaw: 1, typeRaw: 1, repeatingWeekdays: [2],
                                         dueDate: Sched.reminder, notificationActivated: false,
                                         deletedAt: Sched.at(day: -10, hour: 9), records: [])
            context.insert(archive)
            let record = HabitRecordSD(id: Enroll.uuid(3_000 + index), date: Sched.at(day: -12, hour: 8), count: 2)
            context.insert(record)
            archive.records = [record]
        }
        context.insert(StatisticsPresetSD(name: "Preset", isActive: true, habitIDs: [Enroll.uuid(1), Enroll.uuid(3)]))
        try context.save()
    }
}
