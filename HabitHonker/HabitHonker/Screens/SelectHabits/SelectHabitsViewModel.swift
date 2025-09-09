//
//  SelectHabitsViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

// MARK: - UI Model

struct Habit: Identifiable, Hashable {
    let id: UUID
    var name: String
    var color: Color
    var systemImage: String
    var isEnabled: Bool = true
    var isSelected: Bool = false
}

// MARK: - ViewModel

@MainActor
final class SelectHabitsViewModel: ObservableObject {
    // UI state
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var habits: [Habit] = []

    private var existing: [HabitModel] = []
    private var deleted: [HabitModel] = []
    private var all: [HabitModel] = []

    @Published private(set) var selectedHabitIDs: Set<UUID> = []
    var selectedCount: Int { selectedHabitIDs.count }
    let selectionLimit: Int
    
    private let repo: HabitsRepositorySwiftData

    // Track whether selection changed (to avoid unnecessary writes)
    private var initialPresetIDs: Set<UUID> = []
    var isSelectionChanged: Bool { selectedHabitIDs != initialPresetIDs }
    
    init(repo: HabitsRepositorySwiftData, selectionLimit: Int = 4) {
        self.repo = repo
        self.selectionLimit = selectionLimit
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let existingTask = repo.fetchAll()
            async let deletedTask  = repo.fetchAllDeleted()
            async let presetTask   = repo.fetchStatisticsPreset()

            let (existing, deleted, preset) = try await (existingTask, deletedTask, presetTask)

            self.existing = existing
            self.deleted  = deleted
            self.all      = existing + deleted

            // Map to UI
            var ui = HabitMapperUI.toUI(self.all)

            // Apply preset (preselect)
            let presetIDs = Set(preset?.habitIDs ?? [])
            initialPresetIDs = presetIDs
            selectedHabitIDs = presetIDs

            // reflect selection in UI models
            let selectedSet = presetIDs
            for i in ui.indices {
                ui[i].isSelected = selectedSet.contains(ui[i].id)
            }
            habits = ui
        } catch {
            self.error = error
        }
    }

    func toggle(_ habitID: Habit.ID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        guard habits[idx].isEnabled else { return }

        // If selecting new but at limit -> ignore
        if !habits[idx].isSelected && selectedCount >= selectionLimit { return }

        habits[idx].isSelected.toggle()
        if habits[idx].isSelected {
            selectedHabitIDs.insert(habitID)
        } else {
            selectedHabitIDs.remove(habitID)
        }
    }

    func persistPreset(presetName: String? = nil) async {
        guard selectedHabitIDs != initialPresetIDs else { return }
        
        do {
            try await repo.saveStatisticsPreset(Array(selectedHabitIDs), presetName: presetName)
            initialPresetIDs = selectedHabitIDs // update baseline
        } catch {
            self.error = error
        }
    }
}

// MARK: - Mapper

enum HabitMapperUI {
    static func toUI(_ model: HabitModel) -> Habit {
        Habit(
            id: model.id,
            name: model.title,
            color: model.priority.color, // replace on color when colorPicker will be ready
            systemImage: model.icon ?? "empty_icon",
            isEnabled: model.type == .repeating ? true : false, // DueDate tasks not avalible
            isSelected: false
        )
    }

    static func toUI(_ models: [HabitModel]) -> [Habit] {
        models.map(toUI)
    }
}
