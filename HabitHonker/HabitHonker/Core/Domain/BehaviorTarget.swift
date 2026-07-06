//
//  BehaviorTarget.swift
//  HabitHonker
//

import Foundation

struct BehaviorTargetID: Hashable, Codable, Sendable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct BehaviorTarget: Identifiable, Equatable, Codable, Sendable {
    var id: BehaviorTargetID
    var iconName: String?
    var title: String
    var description: String
    var tags: [String]
    var priority: BehaviorPriority
    var schedule: BehaviorSchedule
    var reminderConfig: TargetReminderConfig

    init(
        id: BehaviorTargetID = BehaviorTargetID(),
        iconName: String? = nil,
        title: String,
        description: String = "",
        tags: [String] = [],
        priority: BehaviorPriority = .importantAndUrgent,
        schedule: BehaviorSchedule,
        reminderConfig: TargetReminderConfig = TargetReminderConfig()
    ) {
        self.id = id
        self.iconName = iconName
        self.title = title
        self.description = description
        self.tags = tags
        self.priority = priority
        self.schedule = schedule
        self.reminderConfig = reminderConfig
    }
}
