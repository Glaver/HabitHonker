//
//  StatisticsPreset.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/8/25.
//

import SwiftData
import Foundation

@Model
final class StatisticsPresetSD {
    var id: UUID = UUID()
    var name: String = ""
    var isActive: Bool = false
    var habitIDs: [UUID] = []

    init(id: UUID = UUID(), name: String = "", isActive: Bool = false, habitIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.habitIDs = habitIDs
    }
}
