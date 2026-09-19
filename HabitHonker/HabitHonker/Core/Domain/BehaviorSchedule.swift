//
//  BehaviorSchedule.swift
//  HabitHonker
//

import Foundation

enum BehaviorWeekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

enum BehaviorSchedule: Equatable, Codable, Sendable {
    case repeating(weekdays: Set<BehaviorWeekday>)
    case oneTime(dueDate: Date)
}
