//
//  StatisticsServiceProtocol.swift
//  HabitHonker
//

import Foundation

struct StatisticsSelectionSnapshot {
    let activeHabits: [HabitModel]
    let deletedHabits: [HabitModel]
    let selectedHabitIDs: Set<UUID>
}

protocol StatisticsServiceProtocol {
    func fetchPresetHabits() async throws -> [HabitModel]
    func fetchSelectionSnapshot() async throws -> StatisticsSelectionSnapshot
    func savePresetHabitIDs(_ habitIDs: [UUID], presetName: String?) async throws
}
