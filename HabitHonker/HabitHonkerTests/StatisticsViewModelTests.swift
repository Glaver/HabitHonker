import Combine
import SwiftUI
import XCTest
@testable import HabitHonker

@MainActor
final class StatisticsViewModelTests: XCTestCase {
    func testCompletionEventRegeneratesCalendarWhenSelectedHabitIDsAreUnchanged() async {
        let today = Date()
        let habitID = UUID()
        let statisticsService = StatisticsServiceTestDouble(
            presetHabits: [makeHabit(id: habitID, recordCount: 0, recordDate: today)]
        )
        let habitEvents = StatisticsHabitEventsTestDouble()
        let viewModel = StatisticsViewModel(
            statisticsService: statisticsService,
            habitEvents: habitEvents
        )

        await viewModel.loadPresetHabits()

        let didBuildInitialMonths = await waitForMonths(in: viewModel)
        XCTAssertTrue(didBuildInitialMonths)
        XCTAssertEqual(pillCount(on: today, in: viewModel), 0)

        statisticsService.presetHabits = [
            makeHabit(id: habitID, recordCount: 1, recordDate: today)
        ]
        habitEvents.send(.completed)

        let didUpdatePillCount = await waitForPillCount(1, on: today, in: viewModel)
        XCTAssertTrue(didUpdatePillCount)
    }

    func testChangingSelectedHabitIDsRegeneratesCalendar() async {
        let today = Date()
        let completedHabit = makeHabit(recordCount: 1, recordDate: today)
        let emptyHabit = makeHabit(recordCount: 0, recordDate: today)
        let statisticsService = StatisticsServiceTestDouble(
            presetHabits: [completedHabit, emptyHabit]
        )
        let viewModel = StatisticsViewModel(statisticsService: statisticsService)

        await viewModel.loadPresetHabits()

        let didBuildInitialPills = await waitForPillCount(1, on: today, in: viewModel)
        XCTAssertTrue(didBuildInitialPills)

        guard let completedFilter = viewModel.filterItems.first(where: { $0.id == completedHabit.id }) else {
            return XCTFail("Expected completed habit filter")
        }

        viewModel.toggle(completedFilter)

        let didUpdateSelectionPills = await waitForPillCount(0, on: today, in: viewModel)
        XCTAssertTrue(didUpdateSelectionPills)
    }

    private func makeHabit(
        id: UUID = UUID(),
        recordCount: Int,
        recordDate: Date
    ) -> HabitModel {
        HabitModel(
            id: id,
            icon: "empty_icon",
            iconColor: .red,
            title: "Statistics habit",
            description: "",
            priority: .importantAndUrgent,
            type: .repeating,
            repeating: Weekday.allSet,
            dueDate: recordDate,
            record: recordCount > 0 ? [.init(date: recordDate, count: recordCount)] : []
        )
    }

    private func waitForMonths(
        in viewModel: StatisticsViewModel,
        timeout: TimeInterval = 2
    ) async -> Bool {
        await waitUntil(timeout: timeout) {
            !viewModel.months.isEmpty
        }
    }

    private func waitForPillCount(
        _ expectedCount: Int,
        on date: Date,
        in viewModel: StatisticsViewModel,
        timeout: TimeInterval = 2
    ) async -> Bool {
        await waitUntil(timeout: timeout) {
            !viewModel.months.isEmpty && pillCount(on: date, in: viewModel) == expectedCount
        }
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return condition()
    }

    private func pillCount(on date: Date, in viewModel: StatisticsViewModel) -> Int {
        let calendar = Calendar.current
        return viewModel.months
            .first { calendar.isDate(date, equalTo: $0.monthDate, toGranularity: .month) }?
            .days
            .first { day in
                guard let dayDate = day.date else { return false }
                return calendar.isDate(dayDate, inSameDayAs: date)
            }?
            .pills
            .count ?? 0
    }
}

private final class StatisticsServiceTestDouble: StatisticsServiceProtocol {
    var presetHabits: [HabitModel]
    private(set) var savedHabitIDs: [UUID] = []

    init(presetHabits: [HabitModel]) {
        self.presetHabits = presetHabits
    }

    func fetchPresetHabits() async throws -> [HabitModel] {
        presetHabits
    }

    func fetchSelectionSnapshot() async throws -> StatisticsSelectionSnapshot {
        StatisticsSelectionSnapshot(
            activeHabits: presetHabits,
            deletedHabits: [],
            selectedHabitIDs: Set(presetHabits.map(\.id))
        )
    }

    func savePresetHabitIDs(_ habitIDs: [UUID], presetName: String?) async throws {
        savedHabitIDs = habitIDs
    }
}

private final class StatisticsHabitEventsTestDouble: HabitEventsPublishing {
    private let subject = PassthroughSubject<HabitEvent, Never>()

    var events: AnyPublisher<HabitEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: HabitEvent) {
        subject.send(event)
    }
}
