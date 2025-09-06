//
//  CalendarBuilder.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

final class CalendarBuilder {
    private var calendar: Calendar
    private let locale: Locale
    
    init(calendar: Calendar = .current, locale: Locale = .current) {
        var cal = calendar
        cal.locale = locale
        self.calendar = cal
        self.locale = locale
    }
    
    // Month for a specific anchor date
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
            let pills = demoPills(for: date)
            items.append(DayItem(id: UUID(), date: date, inCurrentMonth: true, isToday: isToday, pills: pills, isEmpty: false))
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
    
    // All 12 months of the year that contains `anchor`
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
    
    // Demo pills so UI is visible immediately
    private func demoPills(for date: Date) -> [Pill] {
        let day = calendar.component(.day, from: date)
        let count = [0,1,2,3,4][day % 5]
        let palette: [Color] = [.blue, .green, .orange, .pink, .red, .purple]
        return (0..<count).map { i in Pill(color: palette[(day + i) % palette.count]) }
    }
}
