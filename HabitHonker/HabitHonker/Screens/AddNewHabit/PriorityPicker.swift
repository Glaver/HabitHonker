//
//  PriorityPicker.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/11/25.
//
import SwiftUI

struct PriorityPicker: View {
    @Binding var priorityEisenhower: HabitModel.PriorityEisenhower {
        didSet {
            print(priorityEisenhower)
        }
    }
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            ForEach(HabitModel.PriorityEisenhower.allCases, id: \.self) { priority in
                PriorityCell(selectedType: $priorityEisenhower, type: priority)
            }
        }
    }
}
