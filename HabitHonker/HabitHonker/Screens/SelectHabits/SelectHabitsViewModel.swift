//
//  SelectHabitsViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

// MARK: - Model

struct Habit: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var color: Color
    var systemImage: String
    var isEnabled: Bool = true
    var isSelected: Bool = false
}

// MARK: - ViewModel

@MainActor
final class SelectHabitsViewModel: ObservableObject {
    @Published var habits: [Habit]
    @EnvironmentObject var viewModel: HabitListViewModel
    
    let selectionLimit: Int = 4

    init(habits: [Habit] = SampleHabits.make()) {
        self.habits = habits
    }

    var selectedCount: Int { habits.filter(\.isSelected).count }

    func toggle(_ habitID: Habit.ID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        // If trying to select a new one while at the limit, do nothing
        if !habits[idx].isSelected && selectedCount >= selectionLimit { return }
        // Ignore taps for disabled items
        guard habits[idx].isEnabled else { return }
        habits[idx].isSelected.toggle()
    }
    
    func loadAllItems() {
        
    }
}

