import SwiftUI
import XCTest
@testable import HabitHonker

final class HabitModelTests: XCTestCase {
    func testCompleteHabitNowCreatesAndIncrementsTodayRecord() {
        var habit = makeHabit(title: "Hydrate")

        XCTAssertFalse(habit.isCompleted(on: Date()))
        XCTAssertEqual(habit.getTodayCount(), 0)

        habit.completeHabitNow()

        XCTAssertTrue(habit.isCompleted(on: Date()))
        XCTAssertEqual(habit.record.count, 1)
        XCTAssertEqual(habit.getTodayCount(), 1)

        habit.completeHabitNow()

        XCTAssertEqual(habit.record.count, 1)
        XCTAssertEqual(habit.getTodayCount(), 2)
    }

    func testSortedKeepsIncompleteHabitsBeforeCompletedAndThenUsesPriority() {
        var completedUrgent = makeHabit(
            title: "Completed urgent",
            priority: .importantAndUrgent
        )
        completedUrgent.completeHabitNow()

        let incompleteLowPriority = makeHabit(
            title: "Low priority",
            priority: .notUrgentAndNotImportant
        )
        let incompleteUrgent = makeHabit(
            title: "Urgent incomplete",
            priority: .importantAndUrgent
        )

        let sorted = HabitSortFilterService.sorted([
            completedUrgent,
            incompleteLowPriority,
            incompleteUrgent
        ])

        XCTAssertEqual(sorted.map(\.id), [
            incompleteUrgent.id,
            incompleteLowPriority.id,
            completedUrgent.id
        ])
    }

    private func makeHabit(
        title: String,
        priority: PriorityEisenhower = .importantAndUrgent
    ) -> HabitModel {
        HabitModel(
            icon: "empty_icon",
            iconColor: .red,
            title: title,
            description: "",
            priority: priority,
            type: .repeating,
            repeating: Weekday.allSet,
            dueDate: Date()
        )
    }
}
