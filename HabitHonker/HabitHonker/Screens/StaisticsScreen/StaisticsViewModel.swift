//
//  StaisticsViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import Combine
import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var items: [HabitModel] = []
    @Published private(set) var habitPresetIDs: [UUID] = []
    
    @Published private(set) var error: Error?
    @Published private(set) var isLoading = false
    
    let repo: HabitsRepositorySwiftData

    init(repo: HabitsRepositorySwiftData) {
        self.repo = repo
    }

    func loadPresetHabits() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let preset = try await repo.fetchStatisticsPreset() else {
                self.items = []
                return
            }

            habitPresetIDs = preset.habitIDs
            
            var resolved: [HabitModel] = []
            
            for id in habitPresetIDs {
                // Try active first
                if let habit = try await repo.fetch(id: id) {
                    resolved.append(habit)
                }
                // If not found, try deleted
                else if let deleted = try await repo.fetchDeleted(id: id) {
                    resolved.append(deleted)
                }
                // If not found at all, skip silently (or log)
            }
            
            self.items = resolved
            print("StatisticsView ID of habits in preset:\(habitPresetIDs)")
        } catch {
            self.error = error
            print("❌ Failed to load habits from preset: \(error)")
        }
    }
}
