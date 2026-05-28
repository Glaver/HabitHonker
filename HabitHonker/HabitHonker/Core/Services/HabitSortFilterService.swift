//
//  HabitSortFilterService.swift
//  HabitHonker
//

import Foundation

enum HabitSortFilterService {
    static func sorted(_ items: [HabitModel]) -> [HabitModel] {
        items.sorted { item1, item2 in
            if item1.isCompletedToday != item2.isCompletedToday {
                return !item1.isCompletedToday
            }
            if item1.priority.rawValue != item2.priority.rawValue {
                return item1.priority.rawValue < item2.priority.rawValue
            }
            return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
        }
    }

    static func filtered(_ items: [HabitModel], mode: HabitLoadMode) -> [HabitModel] {
        switch mode {
        case .all:
            return items

        case .filteredByWeekday(let date):
            let targetWeekday = date.currentWeekday
            return items.filter { item in
                if item.type == .repeating {
                    return item.repeating.contains(targetWeekday)
                } else {
                    return true
                }
            }
        }
    }

    static func habitsForDate(_ items: [HabitModel], date: Date) -> [HabitModel] {
        let weekday = date.currentWeekday
        let calendar = Calendar.current

        return items.filter { habit in
            switch habit.type {
            case .repeating:
                return habit.repeating.contains(weekday)
            case .dueDate:
                return calendar.isDate(habit.dueDate, inSameDayAs: date)
            }
        }
    }

    static func completedHabits(_ items: [HabitModel], on date: Date) -> [HabitModel] {
        items.filter { $0.isCompleted(on: date) }
    }

    static func habitsNotForDate(_ items: [HabitModel], date: Date) -> [HabitModel] {
        let weekday = date.currentWeekday
        let calendar = Calendar.current

        return items.filter { habit in
            switch habit.type {
            case .repeating:
                return !habit.repeating.contains(weekday)
            case .dueDate:
                return !calendar.isDate(habit.dueDate, inSameDayAs: date)
            }
        }
    }

    static func incompleteHabitsForDate(_ items: [HabitModel], date: Date) -> [HabitModel] {
        habitsForDate(items, date: date)
            .filter { !$0.isCompleted(on: date) }
    }

    static func incompleteHabitsNotForDate(_ items: [HabitModel], date: Date) -> [HabitModel] {
        habitsNotForDate(items, date: date)
            .filter { !$0.isCompleted(on: date) }
    }
}
