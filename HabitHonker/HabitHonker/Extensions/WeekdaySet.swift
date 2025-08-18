//
//  WeekdaySet.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/10/25.
//
import SwiftUI

enum Weekday: Int, CaseIterable, Codable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var text: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    var shortSymbol: String {
        let idx = rawValue - 1 // DateFormatter symbols are 0-based
        return DateFormatter().shortWeekdaySymbols[idx]
    }
    
    static var all: [Weekday] = .init(Weekday.allCases)
    static var allSet: Set<Weekday> = .init(Weekday.allCases)
}

struct RepeatHabit: Codable, Equatable {
    var weekdays: Set<Weekday> = []        // e.g. [.monday, .wednesday, .friday]
}

extension Calendar {
    func weekday(for date: Date) -> Weekday {
        Weekday(rawValue: component(.weekday, from: date))!
    }
}
