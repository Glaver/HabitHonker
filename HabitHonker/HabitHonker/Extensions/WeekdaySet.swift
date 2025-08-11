//
//  WeekdaySet.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/10/25.
//
import SwiftUI

//struct WeekdaySet: OptionSet, Codable {
//    let rawValue: UInt8
//
//    static let sunday    = WeekdaySet(rawValue: 1 << 0)
//    static let monday    = WeekdaySet(rawValue: 1 << 1)
//    static let tuesday   = WeekdaySet(rawValue: 1 << 2)
//    static let wednesday = WeekdaySet(rawValue: 1 << 3)
//    static let thursday  = WeekdaySet(rawValue: 1 << 4)
//    static let friday    = WeekdaySet(rawValue: 1 << 5)
//    static let saturday  = WeekdaySet(rawValue: 1 << 6)
//
//    static let weekdays: WeekdaySet = [.monday, .tuesday, .wednesday, .thursday, .friday]
//    static let weekend: WeekdaySet  = [.saturday, .sunday]
//}
//
//extension WeekdaySet {
//    static func from(date: Date, calendar: Calendar = .current) -> WeekdaySet {
//        switch calendar.component(.weekday, from: date) {
//        case 1: return .sunday
//        case 2: return .monday
//        case 3: return .tuesday
//        case 4: return .wednesday
//        case 5: return .thursday
//        case 6: return .friday
//        default: return .saturday
//        }
//    }
//}
