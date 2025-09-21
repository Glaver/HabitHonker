//
//  PriorityPicker.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/11/25.
//
import SwiftUI

struct PriorityPicker: View {
    @Binding var priorityEisenhower: PriorityEisenhower
    let priorityColors: [Color]
    let priorityTitles: [String]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            ForEach(PriorityEisenhower.allCases, id: \.self) { priority in
                PriorityCell(selectedType: $priorityEisenhower,
                             type: priority,
                             color: priorityColors[priority.index],
                             text: priorityTitles[priority.index])
            }
        }
        
    }
}
