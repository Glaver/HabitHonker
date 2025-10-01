//
//  CalendarBuilder.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

// TODO: Add protocols

final class CalendarBuilder {
    private var calendar: Calendar
    private let locale: Locale
    private var dayIndex: [Date: [DayEntry]] = [:]
    
    private let maxPillsPerHabitPerDay = 4

    init(calendar: Calendar = .current, locale: Locale = .current) {
        var cal = calendar
        cal.locale = locale
        cal.timeZone = .current
        self.calendar = cal
        self.locale = locale
    }

    // Call this whenever habits/records change
    func updateHabits(_ habits: [HabitModel]) {
        dayIndex = indexRecordsByDay(habits: habits)
    }

    // MARK: - Month for a specific anchor date
    func makeMonth(for anchor: Date) -> MonthSection {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor))!
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let daysInMonth = range.count

        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var items: [DayItem] = []
        items.append(contentsOf: Array(repeating: .blank, count: leading))

        for day in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            let isToday = calendar.isDateInToday(date)
            let pills = pillsForDate(date)
            items.append(DayItem(id: UUID(),
                                 date: date,
                                 inCurrentMonth: true,
                                 isToday: isToday,
                                 pills: pills,
                                 isEmpty: false))
        }

        let remainder = items.count % 7
        if remainder != 0 {
            items.append(contentsOf: Array(repeating: .blank, count: 7 - remainder))
        }

        let fmt = DateFormatter()
        fmt.locale = locale
        fmt.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        let title = fmt.string(from: monthStart)

        return MonthSection(monthDate: monthStart, title: title, days: items)
    }

    // MARK: - All 12 months of the year that contains `anchor`
    func makeYear(for anchor: Date) -> [MonthSection] {
        let comps = calendar.dateComponents([.year], from: anchor)
        guard let jan1 = calendar.date(from: DateComponents(year: comps.year, month: 1, day: 1)) else {
            return []
        }

        let today = Date()

        return (0..<12).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: jan1) else { return nil }
            // Only include months that are NOT in the future
            if calendar.compare(monthDate, to: today, toGranularity: .month) != .orderedDescending {
                return makeMonth(for: monthDate)
            } else {
                return nil
            }
        }
    }

    // MARK: - build Pills

    private func pillsForDate(_ date: Date) -> [Pill] {
        let key = calendar.startOfDay(for: date)
        let entries = dayIndex[key] ?? []

        // If you want one pill per habit regardless of count, change `repeatCount` to 1.
        let pills = entries.flatMap { entry -> [Pill] in
            let repeatCount = max(1, min(entry.count, maxPillsPerHabitPerDay))
            return Array(repeating: Pill(habitID: entry.habitID, color: entry.color), count: repeatCount)//entry.color), count: repeatCount)
        }
        return pills
    }

    // MARK: - Indexing

    private struct DayEntry {
        let habitID: UUID
        let color: Color
        let count: Int
    }

    private func indexRecordsByDay(habits: [HabitModel]) -> [Date: [DayEntry]] {
        var index: [Date: [DayEntry]] = [:]

        for habit in habits {
            let color = habit.iconColor
            for rec in habit.record {
                let day = calendar.startOfDay(for: rec.date)

                if let existing = index[day]?.firstIndex(where: { $0.habitID == habit.id }) {
                    var arr = index[day]!
                    let old = arr[existing]
                    arr[existing] = DayEntry(habitID: old.habitID, color: old.color, count: old.count + rec.count)
                    index[day] = arr
                } else {
                    index[day, default: []].append(DayEntry(habitID: habit.id, color: color, count: rec.count))
                }
            }
        }
        return index
    }
}
