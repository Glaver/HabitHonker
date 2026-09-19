//
//  StatisticsService.swift
//  HabitHonker
//

import Foundation

struct StatisticsService: StatisticsServiceProtocol {
    private let habitRepository: HabitRepositoryProtocol

    init(habitRepository: HabitRepositoryProtocol) {
        self.habitRepository = habitRepository
    }

    func fetchPresetHabits() async throws -> [HabitModel] {
        guard let presetIDs = try await habitRepository.fetchStatisticsPresetHabitIDs() else {
            return []
        }

        var resolved: [HabitModel] = []
        for id in presetIDs {
            if let habit = try await habitRepository.fetch(id: id) {
                resolved.append(habit)
            } else if let deletedHabit = try await habitRepository.fetchDeleted(id: id) {
                resolved.append(deletedHabit)
            }
        }
        return resolved
    }

    func fetchSelectionSnapshot() async throws -> StatisticsSelectionSnapshot {
        async let activeHabits = habitRepository.fetchAll()
        async let deletedHabits = habitRepository.fetchAllDeleted()
        async let presetIDs = habitRepository.fetchStatisticsPresetHabitIDs()

        let (active, deleted, selectedIDs) = try await (activeHabits, deletedHabits, presetIDs)
        return StatisticsSelectionSnapshot(
            activeHabits: active,
            deletedHabits: deleted,
            selectedHabitIDs: Set(selectedIDs ?? [])
        )
    }

    func savePresetHabitIDs(_ habitIDs: [UUID], presetName: String?) async throws {
        try await habitRepository.saveStatisticsPresetHabitIDs(habitIDs, presetName: presetName)
    }
}
