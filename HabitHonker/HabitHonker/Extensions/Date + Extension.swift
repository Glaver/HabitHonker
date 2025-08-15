//
//  Date + Extension.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/11/25.
//
import Foundation

extension Date {
    func getTimeFrom() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        return dateFormatter.string(from: self)
    }
    
    var currentDayTitle: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        let day = calendar.component(.day, from: self)
        let month = calendar.component(.month, from: self)
        
        let weekdaySymbol = DateFormatter().weekdaySymbols[weekday - 1]
        let monthSymbol = DateFormatter().monthSymbols[month - 1]
        
        return "\(weekdaySymbol) \(day), \(monthSymbol)"
    }
    
    var currentWeekday: Weekday {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        return Weekday(rawValue: weekday) ?? .monday
    }
    
    func isSameDay(as otherDate: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: otherDate)
    }
    
    var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(self)
    }
    
    var isTomorrow: Bool {
        let calendar = Calendar.current
        return calendar.isDateInTomorrow(self)
    }
    
    var isYesterday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInYesterday(self)
    }
    
    var startOfDay: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay) ?? self
    }
    
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var endOfWeek: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfWeek) ?? self
    }
}
