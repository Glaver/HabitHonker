//
//  PriorityCell.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/10/25.
//

import SwiftUI

struct PriorityCell: View {
    @Binding var selectedType: HabitModel.PriorityEisenhower
    var type: HabitModel.PriorityEisenhower
    @Environment(\.colorScheme) var scheme
                        
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
                    .fill(isSelected ? type.color.opacity(Color.opacityForSheme(scheme)) : .clear)
                    .frame(width: 22, height: 48)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
//                    .shadow(color: isSelected ? type.color.opacity(0.4) : .clear, radius: 3, x: 2, y: 2)
//                    .padding(.leading, 10)
//                    .shadow(color: isSelected ? type.color.opacity(0.7) : .clear, radius: 1, x: 0, y: 3)
                
                Text(type.text.replacingOccurrences(of: "/", with: ""))
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(isSelected ? 1 : 0.8))
                    .lineLimit(2)
                    .padding(.leading, 10)
                
                Spacer()
            }
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: isSelected ? type.color.opacity(Color.opacityForSheme(scheme)) : .clear, radius: 5, x: 1, y: 1)
            
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? type.color.opacity(0.4) : .clear, lineWidth: 0.3)
            )
        }
        .buttonStyle(.plain)

        
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
