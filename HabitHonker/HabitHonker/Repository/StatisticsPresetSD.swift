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
    @Attribute(.unique) var id: UUID
    var habitIDs: [UUID] = []
    var presetName: String? // For future feature
    
    init(id: UUID = UUID(), habitIDs: [UUID], presetName: String? = nil) {
        self.id = id
        self.habitIDs = habitIDs
        self.presetName = presetName
    }
}
