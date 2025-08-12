//
//  PriorityCell.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/10/25.
//

import SwiftUI

struct PriorityCell: View {
    @Binding var selectedType: ListHabitItem.PriorityEisenhower
    var type: ListHabitItem.PriorityEisenhower
    
    var isSelected: Bool {
        selectedType == type
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedType = type
            }
        } label: {                       
            HStack() {
                Capsule()
                    .fill(isSelected ? type.color.opacity(0.7) : .clear)
                    .frame(width: 15, height: 38)
                    .glassEffect()
                    .shadow(color: isSelected ? type.color.opacity(0.7) : .clear, radius: 1, x: 0, y: 3)
                
                Text(type.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.leading, 10)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(isSelected ? type.color.opacity(0.8) : .clear, lineWidth: 0.2)
        )
        .shadow(color: isSelected ? type.color.opacity(0.8) : .clear, radius: 5, x: 0, y: 0)
    }
}

/// Helper to preview @Binding
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content

    init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }

    var body: some View { content($value) }
}
