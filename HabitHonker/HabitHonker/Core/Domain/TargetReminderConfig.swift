//
//  TargetReminderConfig.swift
//  HabitHonker
//

import Foundation

struct TargetReminderConfig: Equatable, Codable, Sendable {
    var isEnabled: Bool
    var deliveryTime: Date?

    init(isEnabled: Bool = false, deliveryTime: Date? = nil) {
        self.isEnabled = isEnabled
        self.deliveryTime = deliveryTime
    }
}
