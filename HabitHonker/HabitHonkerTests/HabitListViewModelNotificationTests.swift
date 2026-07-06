import Combine
import SwiftUI
import XCTest
@testable import HabitHonker

@MainActor
final class HabitListViewModelNotificationTests: XCTestCase {
    func testSaveItemWithNotificationsDisabledCancelsPendingRequestsForSavedHabit() async {
        let notifier = NotificationSchedulingSpy()
        let habit = makeHabit(notificationActivated: false)
        let viewModel = makeViewModel(notifier: notifier)

        await viewModel.saveItem(habit)

        XCTAssertEqual(notifier.cancelledIDs, [habit.id])
        XCTAssertTrue(notifier.rescheduledHabits.isEmpty)
    }

    func testSaveItemWithNotificationsEnabledReschedulesSavedHabit() async {
        let notifier = NotificationSchedulingSpy()
        let habit = makeHabit(notificationActivated: true)
        let viewModel = makeViewModel(notifier: notifier)

        await viewModel.saveItem(habit)

        XCTAssertEqual(notifier.rescheduledHabits.map(\.id), [habit.id])
        XCTAssertTrue(notifier.cancelledIDs.isEmpty)
    }

    func testDeleteItemCancelsNotificationsForDeletedHabitWhenEditingItemIsStale() async {
        let notifier = NotificationSchedulingSpy()
        let habitService = HabitServiceSpy()
        let habit = makeHabit(notificationActivated: true)
        let viewModel = makeViewModel(habitService: habitService, notifier: notifier)

        await viewModel.deleteItem(habit)

        XCTAssertEqual(notifier.cancelledIDs, [habit.id])
        XCTAssertEqual(habitService.deletedIDs, [habit.id])
    }

    private func makeViewModel(
        habitService: HabitServiceSpy = HabitServiceSpy(),
        notifier: NotificationSchedulingSpy
    ) -> HabitListViewModel {
        HabitListViewModel(
            habitService: habitService,
            habitEvents: HabitEventsSpy(),
            priorityThemeService: PriorityThemeServiceSpy(),
            backgroundService: BackgroundServiceSpy(),
            notifier: notifier
        )
    }

    private func makeHabit(
        id: UUID = UUID(),
        notificationActivated: Bool
    ) -> HabitModel {
        HabitModel(
            id: id,
            icon: "empty_icon",
            iconColor: .red,
            title: "Notification test",
            description: "",
            priority: .importantAndUrgent,
            type: .repeating,
            repeating: [.monday],
            dueDate: Date().addingTimeInterval(3_600),
            notificationActivated: notificationActivated
        )
    }
}

private final class NotificationSchedulingSpy: HabitNotificationScheduling {
    private(set) var authorizationRequested = false
    private(set) var rescheduledHabits: [HabitModel] = []
    private(set) var cancelledIDs: [UUID] = []
    private(set) var cancelAllCallCount = 0

    func requestAuthorization() async throws {
        authorizationRequested = true
    }

    func reschedule(for habit: HabitModel) async throws {
        rescheduledHabits.append(habit)
    }

    func cancel(for habitID: UUID) async {
        cancelledIDs.append(habitID)
    }

    func cancelAll() async {
        cancelAllCallCount += 1
    }
}

private final class HabitServiceSpy: HabitServiceProtocol {
    var habits: [HabitModel] = []
    private(set) var savedHabits: [HabitModel] = []
    private(set) var deletedIDs: [UUID] = []

    func fetchHabits() async throws -> [HabitModel] {
        habits
    }

    func fetchHabit(id: UUID) async throws -> HabitModel? {
        habits.first { $0.id == id }
    }

    func saveHabit(_ habit: HabitModel) async throws {
        savedHabits.append(habit)
    }

    func deleteHabit(id: UUID) async throws {
        deletedIDs.append(id)
    }

    func completeHabit(id: UUID) async throws -> HabitModel? {
        nil
    }

    func changePriority(id: UUID, to priority: PriorityEisenhower) async throws -> HabitModel? {
        nil
    }

    func fetchDeletedHabits() async throws -> [HabitModel] {
        []
    }

    func fetchDeletedHabit(id: UUID) async throws -> HabitModel? {
        nil
    }

    func restoreDeletedHabit(id: UUID) async throws {}

    func permanentlyDeleteDeleted(id: UUID) async throws {}
}

private final class HabitEventsSpy: HabitEventsPublishing {
    private let subject = PassthroughSubject<HabitEvent, Never>()

    var events: AnyPublisher<HabitEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: HabitEvent) {
        subject.send(event)
    }
}

private struct PriorityThemeServiceSpy: PriorityThemeServiceProtocol {
    func loadColors() async -> [Color] {
        [.red, .yellow, .green, .blue]
    }

    func loadTitles() async -> [String] {
        ["", "", "", ""]
    }

    func setColor(_ color: Color, at index: Int) async {}

    func setTitle(_ title: String, for priority: PriorityEisenhower) async {}

    func setColors(_ colors: [Color]) async {}

    func setTitles(_ titles: [String]) async {}

    func resetToDefaults() async {}
}

private struct BackgroundServiceSpy: BackgroundServiceProtocol {
    func loadBackgroundData() async -> Data? {
        nil
    }

    func saveBackgroundData(_ data: Data) async {}

    func optimizedBackgroundData(from data: Data, maxDimension: CGFloat) async -> Data {
        data
    }

    func clearBackground() async {}
}
