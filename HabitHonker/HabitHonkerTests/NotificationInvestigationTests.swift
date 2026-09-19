import Combine
import SwiftData
import SwiftUI
import UserNotifications
import XCTest
@testable import HabitHonker

/// Mutation regressions assert corrected R1–R4 invariants. Remaining tests named
/// "Reproduces" characterize deferred notification/persistence failure behavior.
@MainActor
final class NotificationInvestigationTests: XCTestCase {
    func testReminderConfigurationRoundTripsThroughSwiftDataInsertAndUpdate() async throws {
        let fixture = try AuditFixture()
        var habit = auditHabit()
        await fixture.vm.saveItem(habit)
        let inserted = try await fixture.repository.fetch(id: habit.id)
        assertHabit(inserted, equals: habit)

        habit.type = .dueDate
        habit.dueDate = habit.dueDate.addingTimeInterval(86_400)
        habit.repeating = [.friday]
        habit.isNotificationActivated = false
        await fixture.vm.saveItem(habit)
        let updated = try await fixture.repository.fetch(id: habit.id)
        let rows = try await fixture.repository.fetchAll()
        assertHabit(updated, equals: habit)
        XCTAssertEqual(rows.count, 1)
    }

    func testReproducesOrphanAlarmWhenUpsertFailsAfterScheduling() async throws {
        let fixture = try AuditFixture()
        let habit = auditHabit()
        fixture.repository.failUpsert = true
        await fixture.vm.saveItem(habit)
        let saved = try await fixture.repository.fetch(id: habit.id)
        XCTAssertNil(saved)
        XCTAssertEqual(fixture.notifier.pending[habit.id], habit)
        XCTAssertNotNil(fixture.vm.error)
    }

    func testReproducesLostAlarmWhenDisablingFailsToPersist() async throws {
        let fixture = try AuditFixture()
        let original = auditHabit()
        await fixture.vm.saveItem(original)
        var disabled = original
        disabled.isNotificationActivated = false
        fixture.repository.failUpsert = true
        await fixture.vm.saveItem(disabled)
        let saved = try await fixture.repository.fetch(id: original.id)
        assertHabit(saved, equals: original)
        XCTAssertNil(fixture.notifier.pending[original.id])
        XCTAssertNotNil(fixture.vm.error)
    }

    func testReproducesLostAlarmWhenDeleteFailsToPersist() async throws {
        let fixture = try AuditFixture()
        let habit = auditHabit()
        await fixture.vm.saveItem(habit)
        fixture.repository.failDelete = true
        await fixture.vm.deleteItem(habit)
        let saved = try await fixture.repository.fetch(id: habit.id)
        assertHabit(saved, equals: habit)
        XCTAssertNil(fixture.notifier.pending[habit.id])
        XCTAssertNotNil(fixture.vm.error)
    }

    func testReproducesEnabledRowAndHiddenErrorWhenSchedulingThrows() async throws {
        let fixture = try AuditFixture()
        let habit = auditHabit()
        fixture.notifier.failScheduling = true
        await fixture.vm.saveItem(habit)
        let saved = try await fixture.repository.fetch(id: habit.id)
        assertHabit(saved, equals: habit)
        XCTAssertTrue(fixture.notifier.pending.isEmpty)
        XCTAssertNil(fixture.vm.error, "Scheduling error is swallowed, unlike persistence errors")
    }

    func testSaveKeepsSubmittedHabitAfterOtherCompletionDuringScheduling() async throws {
        let fixture = try AuditFixture()
        var edited = auditHabit(title: "Original A")
        let other = auditHabit(title: "B")
        try await fixture.repository.upsert(edited)
        try await fixture.repository.upsert(other)
        await fixture.vm.load()
        edited.title = "Draft A"
        let gate = AuditGate()
        fixture.notifier.nextScheduleGate = gate
        let save = Task { await fixture.vm.saveItem(edited) }
        await fulfillment(of: [gate.entered], timeout: 5)
        await fixture.vm.habitCompleteWith(id: other.id)
        XCTAssertEqual(fixture.vm.item.id, other.id)
        await gate.open()
        await save.value
        let storedA = try await fixture.repository.fetch(id: edited.id)
        let storedB = try await fixture.repository.fetch(id: other.id)
        XCTAssertEqual(storedA?.title, "Draft A")
        XCTAssertEqual(storedB?.getTodayCount(), 1)
        XCTAssertEqual(fixture.repository.upsertArguments.last?.id, edited.id)
        XCTAssertEqual(fixture.notifier.pending[edited.id]?.title, "Draft A")
    }

    func testSaveKeepsSubmittedHabitAfterOtherCompletionDuringCancellation() async throws {
        let fixture = try AuditFixture()
        var edited = auditHabit(title: "Original A")
        let other = auditHabit(title: "B")
        try await fixture.repository.upsert(edited)
        try await fixture.repository.upsert(other)
        await fixture.vm.load()
        edited.title = "Draft A"
        edited.isNotificationActivated = false
        let gate = AuditGate()
        fixture.notifier.nextCancelGate = gate
        let save = Task { await fixture.vm.saveItem(edited) }
        await fulfillment(of: [gate.entered], timeout: 5)
        await fixture.vm.habitCompleteWith(id: other.id)
        await gate.open()
        await save.value
        let stored = try await fixture.repository.fetch(id: edited.id)
        XCTAssertEqual(stored?.title, "Draft A")
        XCTAssertEqual(stored?.isNotificationActivated, false)
        let storedB = try await fixture.repository.fetch(id: other.id)
        XCTAssertEqual(storedB?.getTodayCount(), 1)
        XCTAssertNil(fixture.notifier.pending[edited.id])
        XCTAssertEqual(fixture.repository.upsertArguments.last?.id, edited.id)
    }

    func testSaveUsesSubmittedValueForPersistenceAndMemoryAfterOtherCompletion() async throws {
        let fixture = try AuditFixture()
        var edited = auditHabit(title: "Original A")
        let other = auditHabit(title: "B")
        try await fixture.repository.upsert(edited)
        try await fixture.repository.upsert(other)
        await fixture.vm.load()
        edited.title = "Draft A"
        let gate = AuditGate()
        fixture.repository.nextUpsertGate = gate
        let save = Task { await fixture.vm.saveItem(edited) }
        await fulfillment(of: [gate.entered], timeout: 5)
        await fixture.vm.habitCompleteWith(id: other.id)
        await gate.open()
        await save.value
        let storedA = try await fixture.repository.fetch(id: edited.id)
        XCTAssertEqual(storedA?.title, "Draft A", "Argument already captured by value")
        XCTAssertEqual(fixture.vm.items.first { $0.id == edited.id }?.title, "Draft A")
        XCTAssertEqual(fixture.vm.items.first { $0.id == other.id }?.getTodayCount(), 1)
        XCTAssertEqual(fixture.vm.item.id, other.id)
    }

    func testDeleteWaitsForSaveThenRemovesSwiftDataRowAndSimulatedAlarm() async throws {
        let fixture = try AuditFixture()
        var habit = auditHabit(title: "Original")
        await fixture.vm.saveItem(habit)
        habit.title = "Pending edit"
        let gate = AuditGate()
        fixture.notifier.nextScheduleGate = gate
        let save = Task { await fixture.vm.saveItem(habit) }
        await fulfillment(of: [gate.entered], timeout: 5)
        let requested = expectation(description: "Delete submitted")
        let delete = Task {
            requested.fulfill()
            await fixture.vm.deleteItem(habit)
        }
        await fulfillment(of: [requested], timeout: 5)
        XCTAssertTrue(fixture.repository.deletedIDs.isEmpty)
        await gate.open()
        await save.value
        await delete.value
        let active = try await fixture.repository.fetch(id: habit.id)
        let archived = try await fixture.repository.fetchDeleted(id: habit.id)
        XCTAssertNil(active)
        XCTAssertEqual(archived?.title, "Pending edit")
        XCTAssertNil(fixture.notifier.pending[habit.id])
        XCTAssertFalse(fixture.vm.items.contains { $0.id == habit.id })
    }

    func testDeleteWaitsForSaveThenRemovesRealRequestsAndSwiftDataRow() async throws {
        let scheduler = AuditGatedRealScheduler()
        let fixture = try AuditFixture(scheduler: scheduler)
        var habit = auditHabit(title: "Original")
        let id = habit.id
        defer { Task { await scheduler.cancel(for: id) } }
        try await requireScheduling(scheduler.base, habit: habit)
        await fixture.vm.saveItem(habit)
        habit.title = "Resumed edit"
        let gate = AuditGate()
        scheduler.nextGate = gate
        let save = Task { await fixture.vm.saveItem(habit) }
        await fulfillment(of: [gate.entered], timeout: 5)
        let requested = expectation(description: "Delete submitted")
        let delete = Task {
            requested.fulfill()
            await fixture.vm.deleteItem(habit)
        }
        await fulfillment(of: [requested], timeout: 5)
        XCTAssertTrue(fixture.repository.deletedIDs.isEmpty)
        await gate.open()
        await save.value
        await delete.value
        let active = try await fixture.repository.fetch(id: id)
        let pending = await requests(for: id)
        let archived = try await fixture.repository.fetchDeleted(id: id)
        XCTAssertNil(active)
        XCTAssertTrue(pending.isEmpty)
        XCTAssertEqual(archived?.title, "Resumed edit")
        XCTAssertFalse(fixture.vm.items.contains { $0.id == id })
    }

    func testCompletionWaitsForSaveAndPreservesEditAndCompletion() async throws {
        let fixture = try AuditFixture()
        var habit = auditHabit(title: "Original")
        try await fixture.repository.upsert(habit)
        await fixture.vm.load()
        habit.title = "Edited"
        let gate = AuditGate()
        fixture.repository.nextUpsertGate = gate
        let save = Task { await fixture.vm.saveItem(habit) }
        await fulfillment(of: [gate.entered], timeout: 5)
        let requested = expectation(description: "Completion submitted")
        let complete = Task {
            requested.fulfill()
            await fixture.vm.habitCompleteWith(id: habit.id)
        }
        await fulfillment(of: [requested], timeout: 5)
        XCTAssertEqual(fixture.repository.upsertArguments.count, 2, "Seed and suspended Save only")
        await gate.open()
        await save.value
        await complete.value
        let stored = try await fixture.repository.fetch(id: habit.id)
        XCTAssertEqual(stored?.title, "Edited")
        XCTAssertEqual(stored?.getTodayCount(), 1)
        XCTAssertEqual(fixture.vm.items.first { $0.id == habit.id }?.title, "Edited")
        XCTAssertEqual(fixture.vm.items.first { $0.id == habit.id }?.getTodayCount(), 1)
    }

    func testQueuedCompletionsBothApplyToLatestState() async throws {
        let fixture = try AuditFixture()
        let habit = auditHabit()
        try await fixture.repository.upsert(habit)
        let gate = AuditGate()
        fixture.repository.nextUpsertGate = gate
        let first = Task { await fixture.vm.habitCompleteWith(id: habit.id) }
        await fulfillment(of: [gate.entered], timeout: 5)
        let requested = expectation(description: "Second completion submitted")
        let second = Task {
            requested.fulfill()
            await fixture.vm.habitCompleteWith(id: habit.id)
        }
        await fulfillment(of: [requested], timeout: 5)
        XCTAssertEqual(fixture.repository.upsertArguments.count, 2)
        await gate.open()
        await first.value
        await second.value
        let stored = try await fixture.repository.fetch(id: habit.id)
        XCTAssertEqual(stored?.getTodayCount(), 2)
        XCTAssertEqual(fixture.vm.items.first { $0.id == habit.id }?.getTodayCount(), 2)
    }

    func testCompletionQueuedAfterDeleteDoesNotRecreateHabit() async throws {
        let fixture = try AuditFixture()
        let habit = auditHabit()
        await fixture.vm.saveItem(habit)
        let gate = AuditGate()
        fixture.notifier.nextCancelGate = gate
        let delete = Task { await fixture.vm.deleteItem(habit) }
        await fulfillment(of: [gate.entered], timeout: 5)
        let requested = expectation(description: "Completion submitted after delete")
        let complete = Task {
            requested.fulfill()
            await fixture.vm.habitCompleteWith(id: habit.id)
        }
        await fulfillment(of: [requested], timeout: 5)
        XCTAssertEqual(fixture.repository.upsertArguments.count, 1)
        await gate.open()
        await delete.value
        await complete.value
        let stored = try await fixture.repository.fetch(id: habit.id)
        XCTAssertNil(stored)
        XCTAssertFalse(fixture.vm.items.contains { $0.id == habit.id })
        XCTAssertNil(fixture.notifier.pending[habit.id])
        XCTAssertEqual(fixture.repository.upsertArguments.count, 1)
    }

    func testSameHabitSavesAreQueuedAndNewestSubmissionWins() async throws {
        let fixture = try AuditFixture()
        let first = auditHabit(title: "First")
        var newer = first
        newer.title = "Newer edit"
        let gate = AuditGate()
        fixture.notifier.nextScheduleGate = gate
        let save = Task { await fixture.vm.saveItem(first) }
        await fulfillment(of: [gate.entered], timeout: 5)
        let requested = expectation(description: "Second save submitted")
        let second = Task {
            requested.fulfill()
            await fixture.vm.saveItem(newer)
        }
        await fulfillment(of: [requested], timeout: 5)
        XCTAssertEqual(fixture.notifier.scheduleArguments.map(\.title), ["First"])
        await gate.open()
        await save.value
        await second.value
        let stored = try await fixture.repository.fetch(id: first.id)
        XCTAssertEqual(stored?.title, "Newer edit")
        XCTAssertEqual(fixture.vm.items.first { $0.id == first.id }?.title, "Newer edit")
        XCTAssertEqual(fixture.notifier.scheduleArguments.map(\.title), ["First", "Newer edit"])
        XCTAssertEqual(fixture.notifier.pending[first.id]?.title, "Newer edit")
    }

    func testDifferentHabitSaveFinishesWhileFirstHabitIsBlocked() async throws {
        let fixture = try AuditFixture()
        let first = auditHabit(title: "First")
        let different = auditHabit(title: "Different habit")
        let gate = AuditGate()
        fixture.notifier.nextScheduleGate = gate
        let save = Task { await fixture.vm.saveItem(first) }
        await fulfillment(of: [gate.entered], timeout: 5)
        let finished = expectation(description: "Unrelated save finished")
        let other = Task {
            await fixture.vm.saveItem(different)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 5)
        let storedB = try await fixture.repository.fetch(id: different.id)
        let storedA = try await fixture.repository.fetch(id: first.id)
        XCTAssertEqual(storedB?.title, "Different habit")
        XCTAssertNil(storedA)
        await gate.open()
        await save.value
        await other.value
        let rows = try await fixture.repository.fetchAll()
        XCTAssertEqual(Set(rows.map(\.id)), [first.id, different.id])
    }

    func testRealSchedulerPersistsEnabledEmptyWeekdaysWithNoRequests() async throws {
        let fixture = try AuditFixture(realScheduler: true)
        var habit = auditHabit()
        habit.repeating = []
        await fixture.vm.saveItem(habit)
        let saved = try await fixture.repository.fetch(id: habit.id)
        let pending = await requests(for: habit.id)
        assertHabit(saved, equals: habit)
        XCTAssertTrue(pending.isEmpty)
        XCTAssertNil(fixture.vm.error)
    }

    func testRealSchedulerPersistsEnabledPastOneTimeWithNoRequests() async throws {
        let fixture = try AuditFixture(realScheduler: true)
        var habit = auditHabit()
        habit.type = .dueDate
        habit.dueDate = Date().addingTimeInterval(-3_600)
        await fixture.vm.saveItem(habit)
        let saved = try await fixture.repository.fetch(id: habit.id)
        let pending = await requests(for: habit.id)
        assertHabit(saved, equals: habit)
        XCTAssertTrue(pending.isEmpty)
        XCTAssertNil(fixture.vm.error)
    }

    func testRealSchedulerTypeWeekdayTimeDisableAndDeleteTransitions() async throws {
        let fixture = try AuditFixture(realScheduler: true)
        let scheduler = HabitNotificationService()
        var habit = auditHabit()
        let id = habit.id
        defer { Task { await scheduler.cancel(for: id) } }
        // Probe the actual service directly so VM's try? cannot disguise an OS refusal.
        try await requireScheduling(scheduler, habit: habit)
        await fixture.vm.saveItem(habit)
        await assertRequestIDs(id, weekdays: [2, 4])

        habit.repeating = [.wednesday]
        habit.dueDate = habit.dueDate.addingTimeInterval(7_200)
        await fixture.vm.saveItem(habit)
        await assertRequestIDs(id, weekdays: [4])
        let repeating = await requests(for: id)
        let time = Calendar.current.dateComponents([.hour, .minute], from: habit.dueDate)
        let trigger = try XCTUnwrap(repeating.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, time.hour)
        XCTAssertEqual(trigger.dateComponents.minute, time.minute)

        habit.type = .dueDate
        await fixture.vm.saveItem(habit)
        let oneTime = await requests(for: id)
        XCTAssertEqual(oneTime.map(\.identifier), ["habit.\(id.uuidString)"])
        XCTAssertEqual(oneTime.first?.trigger?.repeats, false)

        habit.type = .repeating
        habit.repeating = [.monday, .friday]
        await fixture.vm.saveItem(habit)
        await assertRequestIDs(id, weekdays: [2, 6])
        let enabled = try await fixture.repository.fetch(id: id)
        assertHabit(enabled, equals: habit)

        habit.isNotificationActivated = false
        await fixture.vm.saveItem(habit)
        let disabledRequests = await requests(for: id)
        let disabled = try await fixture.repository.fetch(id: id)
        XCTAssertTrue(disabledRequests.isEmpty)
        assertHabit(disabled, equals: habit)

        habit.isNotificationActivated = true
        await fixture.vm.saveItem(habit)
        await assertRequestIDs(id, weekdays: [2, 6])
        await fixture.vm.deleteItem(habit)
        let deletedRequests = await requests(for: id)
        let deleted = try await fixture.repository.fetch(id: id)
        let archived = try await fixture.repository.fetchDeleted(id: id)
        XCTAssertTrue(deletedRequests.isEmpty)
        XCTAssertNil(deleted)
        assertHabit(archived, equals: habit)
    }

    func testRealSchedulerCurrentMinuteOneTimeTrigger() async throws {
        let fixture = try AuditFixture(realScheduler: true)
        let scheduler = HabitNotificationService()
        var habit = auditHabit()
        let id = habit.id
        defer { Task { await scheduler.cancel(for: id) } }
        try await requireScheduling(scheduler, habit: habit)
        let now = Date()
        let minute = try XCTUnwrap(Calendar.current.dateInterval(of: .minute, for: now))
        // Do not use sleeps or let a minute rollover masquerade as a scheduler defect.
        guard minute.end.timeIntervalSince(now) > 10 else {
            throw XCTSkip("Too close to a minute boundary for this wall-clock integration probe")
        }
        habit.type = .dueDate
        habit.dueDate = minute.end.addingTimeInterval(-1)
        try await scheduler.reschedule(for: habit)
        let pending = await requests(for: id)
        guard Date() < habit.dueDate else { throw XCTSkip("Probe crossed its date boundary") }
        // A future date within the current minute passes the guard, but the actual
        // minute-precision request has no future matching delivery date.
        let observation = "Current-minute request count: \(pending.count); next dates: \(pending.map { String(describing: ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()) })"
        let attachment = XCTAttachment(string: observation)
        attachment.lifetime = .keepAlways
        add(attachment)
        print(observation)
        XCTAssertTrue(pending.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() == nil })
        await fixture.vm.saveItem(habit)
        let saved = try await fixture.repository.fetch(id: id)
        assertHabit(saved, equals: habit)
        XCTAssertNil(fixture.vm.error)
    }

    private func assertHabit(_ actual: HabitModel?, equals expected: HabitModel,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(actual, file: file, line: line)
        XCTAssertEqual(actual?.id, expected.id, file: file, line: line)
        XCTAssertEqual(actual?.title, expected.title, file: file, line: line)
        XCTAssertEqual(actual?.type, expected.type, file: file, line: line)
        XCTAssertEqual(actual?.repeating, expected.repeating, file: file, line: line)
        XCTAssertEqual(actual?.dueDate, expected.dueDate, file: file, line: line)
        XCTAssertEqual(actual?.isNotificationActivated, expected.isNotificationActivated, file: file, line: line)
        XCTAssertEqual(actual?.record, expected.record, file: file, line: line)
    }

    private func requests(for id: UUID) async -> [UNNotificationRequest] {
        let all = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return all.filter { $0.identifier == "habit.\(id.uuidString)" ||
            $0.identifier.hasPrefix("habit.\(id.uuidString).wd.") }
    }

    private func assertRequestIDs(_ id: UUID, weekdays: [Int],
                                  file: StaticString = #filePath, line: UInt = #line) async {
        let actual = await requests(for: id)
        XCTAssertEqual(Set(actual.map(\.identifier)),
                       Set(weekdays.map { "habit.\(id.uuidString).wd.\($0)" }), file: file, line: line)
    }

    private func requireScheduling(_ scheduler: HabitNotificationService, habit: HabitModel) async throws {
        do {
            try await scheduler.reschedule(for: habit)
        } catch {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied || settings.authorizationStatus == .notDetermined {
                throw XCTSkip("OS refused scheduling without notification permission: \(error)")
            }
            throw error
        }
        let pending = await requests(for: habit.id)
        guard !pending.isEmpty else {
            throw XCTSkip("OS accepted add but retained no requests; integration prerequisite unavailable")
        }
    }
}

private func auditHabit(title: String = "Notification audit") -> HabitModel {
    HabitModel(iconColor: .red, title: title, type: .repeating,
               repeating: [.monday, .wednesday], dueDate: Date().addingTimeInterval(86_400),
               notificationActivated: true)
}

/// A one-use handshake; tests wait for entry, perform a mutation, then release.
/// No test sleep or scheduler timing is used to force the concurrency interleavings.
private actor AuditGate {
    nonisolated let entered = XCTestExpectation(description: "Dependency reached suspension point")
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func pause() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            entered.fulfill()
            if isOpen { self.continuation = nil; continuation.resume() }
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

/// Holds the scheduling dependency at its async boundary, then delegates to the
/// unmodified production scheduler. Does not intercept UNUserNotificationCenter.
private final class AuditGatedRealScheduler: HabitNotificationScheduling {
    let base = HabitNotificationService()
    var nextGate: AuditGate?
    func requestAuthorization() async throws { try await base.requestAuthorization() }
    func reschedule(for habit: HabitModel) async throws {
        let gate = nextGate
        nextGate = nil
        await gate?.pause()
        try await base.reschedule(for: habit)
    }
    func cancel(for habitID: UUID) async { await base.cancel(for: habitID) }
    func cancelAll() async { await base.cancelAll() }
}

private enum AuditFailure: Error { case persistence, scheduling }

/// Models a notifier that can suspend before adding, then add after a concurrent
/// cancellation. Its pending map is NOT evidence of actual OS request behavior.
private final class AuditNotifier: HabitNotificationScheduling {
    var pending: [UUID: HabitModel] = [:]
    var scheduleArguments: [HabitModel] = []
    var nextScheduleGate: AuditGate?
    var nextCancelGate: AuditGate?
    var failScheduling = false

    func requestAuthorization() async throws {}
    func reschedule(for habit: HabitModel) async throws {
        scheduleArguments.append(habit)
        pending.removeValue(forKey: habit.id)
        let gate = nextScheduleGate
        nextScheduleGate = nil
        await gate?.pause()
        if failScheduling { throw AuditFailure.scheduling }
        pending[habit.id] = habit
    }
    func cancel(for habitID: UUID) async {
        pending.removeValue(forKey: habitID)
        let gate = nextCancelGate
        nextCancelGate = nil
        await gate?.pause()
    }
    func cancelAll() async { pending.removeAll() }
}

/// Injects failure/suspension at the protocol seam; every successful operation
/// runs through the production SwiftData repository and real model mapping.
private final class AuditRepository: HabitRepositoryProtocol {
    let base: SwiftDataHabitRepository
    var failUpsert = false
    var failDelete = false
    var nextUpsertGate: AuditGate?
    var upsertArguments: [HabitModel] = []
    var deletedIDs: [UUID] = []

    init(_ container: ModelContainer) { base = SwiftDataHabitRepository(container: container) }
    func fetchAll() async throws -> [HabitModel] { try await base.fetchAll() }
    func fetch(id: UUID) async throws -> HabitModel? { try await base.fetch(id: id) }
    func upsert(_ item: HabitModel) async throws {
        upsertArguments.append(item)
        let gate = nextUpsertGate
        nextUpsertGate = nil
        await gate?.pause()
        if failUpsert { throw AuditFailure.persistence }
        try await base.upsert(item)
    }
    func delete(id: UUID) async throws {
        deletedIDs.append(id)
        if failDelete { throw AuditFailure.persistence }
        try await base.delete(id: id)
    }
    func fetchAllDeleted() async throws -> [HabitModel] { try await base.fetchAllDeleted() }
    func fetchDeleted(id: UUID) async throws -> HabitModel? { try await base.fetchDeleted(id: id) }
    func restoreDeletedHabit(id: UUID) async throws { try await base.restoreDeletedHabit(id: id) }
    func permanentlyDeleteDeleted(id: UUID) async throws { try await base.permanentlyDeleteDeleted(id: id) }
    func fetchStatisticsPresetHabitIDs() async throws -> [UUID]? {
        try await base.fetchStatisticsPresetHabitIDs()
    }
    func saveStatisticsPresetHabitIDs(_ habitIDs: [UUID], presetName: String?) async throws {
        try await base.saveStatisticsPresetHabitIDs(habitIDs, presetName: presetName)
    }
}

@MainActor
private final class AuditFixture {
    let repository: AuditRepository
    let notifier = AuditNotifier()
    let vm: HabitListViewModel

    init(realScheduler: Bool = false, scheduler: HabitNotificationScheduling? = nil) throws {
        let schema = Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        repository = AuditRepository(container)
        let events = AuditEvents()
        vm = HabitListViewModel(
            habitService: HabitService(repository: repository, habitEvents: events),
            habitEvents: events, priorityThemeService: AuditTheme(), backgroundService: AuditBackground(),
            notifier: scheduler ?? (realScheduler ? HabitNotificationService() : notifier))
    }
}

/// Suppress automatic list reloads to observe the mutation's own memory update.
/// Production event subscribers only load items; they never mutate self.item.
private final class AuditEvents: HabitEventsPublishing {
    var events: AnyPublisher<HabitEvent, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }
    func send(_ event: HabitEvent) {}
}
private struct AuditTheme: PriorityThemeServiceProtocol {
    func loadColors() async -> [Color] { [.red, .yellow, .green, .blue] }
    func loadTitles() async -> [String] { ["", "", "", ""] }
    func setColor(_ color: Color, at index: Int) async {}
    func setTitle(_ title: String, for priority: PriorityEisenhower) async {}
    func setColors(_ colors: [Color]) async {}
    func setTitles(_ titles: [String]) async {}
    func resetToDefaults() async {}
}
private struct AuditBackground: BackgroundServiceProtocol {
    func loadBackgroundData() async -> Data? { nil }
    func saveBackgroundData(_ data: Data) async {}
    func optimizedBackgroundData(from data: Data, maxDimension: CGFloat) async -> Data { data }
    func clearBackground() async {}
}
