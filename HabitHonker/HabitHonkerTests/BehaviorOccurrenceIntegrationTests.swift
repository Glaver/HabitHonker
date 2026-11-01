import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

@MainActor
final class BehaviorOccurrenceIntegrationTests: XCTestCase {
    func testEnrollmentBaselineThenRealScheduleEditPreservesHistoricalOwnership() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store, Sched.HabitSeed(weekdays: [1, 2, 3, 4, 5, 6, 7], notification: false))
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        _ = try await Enroll.service(repository).enroll(Enroll.request())
        let clock = ScheduleTestClock(Sched.at(day: 2, hour: 0))
        let service = makeService(repository, clock)
        let before = try plan(store, at: Sched.at(day: 1, hour: 12))
        XCTAssertEqual(try D.planned(before).scheduleRevisionID, Sched.baselineID)
        let loaded = try await service.fetchHabit(id: Sched.targetUUID)
        var habit = try XCTUnwrap(loaded)
        habit.repeating = [.wednesday, .thursday]
        _ = try await service.updateHabit(habit)
        XCTAssertEqual(try plan(store, at: Sched.at(day: 1, hour: 12)), before)
        XCTAssertEqual(try D.planned(plan(store, at: clock.now)).scheduleRevisionID, Sched.changeID(1))
        XCTAssertEqual(try plan(store, at: Sched.at(day: 4, hour: 12)), .noOccurrence(.weekdayNotSelected))
        try Enroll.assertNoRewardRows(store)
        try Enroll.assertZeroProjection(Enroll.onlyProfile(store))
    }

    func testCreateAfterEnrollmentThenDeleteAndRestore() async throws {
        let store = try TxStore.memory()
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        _ = try await Enroll.service(repository).enroll(Enroll.request())
        let clock = ScheduleTestClock(Sched.at(day: 1, hour: 12))
        let service = makeService(repository, clock)
        _ = try await service.createHabit(HabitModel(id: Sched.targetUUID, icon: "atom", iconColor: .red,
            title: "New", description: "", priority: .importantAndUrgent, type: .repeating,
            repeating: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday],
            dueDate: Sched.reminder, notificationActivated: false))
        XCTAssertEqual(try Sched.rows(store).map(\.logicalRevisionID), [Sched.changeID(1)])
        XCTAssertEqual(try D.planned(plan(store, at: clock.now)).scheduleRevisionID, Sched.changeID(1))
        clock.now = Sched.at(day: 2, hour: 12)
        try await service.deleteHabit(id: Sched.targetUUID)
        let deletedAt = clock.now
        let closed = try Sched.rows(store)
        XCTAssertEqual(closed.map(\.logicalRevisionID), [Sched.changeID(1)], "delete opens no replacement")
        XCTAssertEqual(closed.first?.effectiveTo, deletedAt)
        XCTAssertEqual(try plan(store, at: deletedAt), .noOccurrence(.noActiveRevision))
        XCTAssertEqual(try plan(store, at: deletedAt.addingTimeInterval(3600)), .noOccurrence(.noActiveRevision))
        clock.now = Sched.at(day: 3, hour: 12)
        try await service.restoreDeletedHabit(id: Sched.targetUUID)
        XCTAssertEqual(try D.planned(plan(store, at: clock.now)).scheduleRevisionID, Sched.changeID(2))
        XCTAssertEqual(try plan(store, at: deletedAt.addingTimeInterval(3600)), .noOccurrence(.noActiveRevision))
        XCTAssertEqual(try D.planned(plan(store, at: Sched.at(day: 1, hour: 12))).scheduleRevisionID, Sched.changeID(1))
        try Enroll.assertNoRewardRows(store)
    }

    func testActualDeviceZoneChangesCannotChangeEnrolledPlanning() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store, Sched.HabitSeed(weekdays: [1, 2, 3, 4, 5, 6, 7], notification: false))
        _ = try await Enroll.service(store).enroll(Enroll.request())
        let action = D.date("2027-01-15T01:00:00Z")
        var results: [BehaviorOccurrencePlan] = []
        for zone in ["Asia/Tokyo", "Europe/London"] {
            try await Enroll.withDeviceTimeZone(zone) {
                XCTAssertEqual(TimeZone.current.identifier, zone)
                XCTAssertEqual(NSTimeZone.default.identifier, zone)
                results.append(try self.plan(store, at: action))
            }
        }
        XCTAssertEqual(results[0], results[1])
        XCTAssertEqual(try D.planned(results[0]).localDay.canonicalKey, "2027-01-14")
    }

    func testPlanningWritesNothingAndLiveCompletionRemainsLegacy() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store, Sched.HabitSeed(notification: false))
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        _ = try await Enroll.service(repository).enroll(Enroll.request())
        let before = try TxStore.state(store)
        _ = try D.planned(plan(store, at: Sched.at(day: 2, hour: 12)))
        XCTAssertEqual(try TxStore.state(store), before)
        let service = makeService(repository, ScheduleTestClock(Sched.at(day: 2, hour: 12)))
        _ = try await service.completeHabit(id: Sched.targetUUID)
        XCTAssertEqual(try Sched.recordRowCount(store), 1)
        try Enroll.assertNoRewardRows(store)
        try Enroll.assertZeroProjection(Enroll.onlyProfile(store))
    }

    private func makeService(_ repository: HabitsRepositorySwiftData, _ clock: ScheduleTestClock) -> HabitService {
        HabitService(repository: SwiftDataHabitRepository(repository: repository), habitEvents: ScheduleSilentEvents(),
                     now: { clock.now }, calendar: { enrollmentLACalendar() })
    }

    private func plan(_ store: ModelContainer, at: Date) throws -> BehaviorOccurrencePlan {
        let context = ModelContext(store)
        let profiles = try context.fetch(FetchDescriptor<GamificationProfileSD>())
        let rows = try context.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>()).filter { $0.targetID == Sched.targetUUID }
        guard case let .enrolled(policy) = BehaviorScheduleEnrollment.resolve(
            profiles: profiles.map(BehaviorScheduleRevisionMapper.profileFacts), revisionHistoryExists: { !rows.isEmpty }) else {
            throw NSError(domain: "EnrollmentFixture", code: 1)
        }
        return BehaviorOccurrencePlanner().plan(BehaviorOccurrencePlanningInput(targetID: Sched.target, policy: policy,
            revisions: rows.map(BehaviorScheduleRevisionMapper.facts), actionAt: at))
    }
}
