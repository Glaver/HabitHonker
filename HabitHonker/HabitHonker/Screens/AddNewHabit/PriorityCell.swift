//
//  PriorityCell.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/10/25.
//

import SwiftUI

struct PriorityCell: View {
    var title: String = "Important / Urgent"
    var priorityColor: Color = .red
//    @Binding var isSelected: Bool

    var isSelected: Bool
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
//                self.isSelected.toggle()
            }
        } label: {
            HStack() {
                Capsule()
                    .fill(priorityColor.opacity(0.8))
                    .frame(width: 15, height: 38)
                    .glassEffect()
                    .shadow(color: priorityColor.opacity(0.7), radius: 1, x: 0, y: 3)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.leading, 10)
                
                
                
                
                // Right circular selector
                
                //                    Circle()
//                        .stroke(Color.gray.opacity(0.35), lineWidth: 2)
//                    if isSelected {
//                        Circle()
//                            .fill(.blue)
//                            .padding(4)
//                        Image(systemName: "checkmark")
//                            .font(.system(size: 12, weight: .bold))
//                            .foregroundColor(.white)
//                    }
                
            }
            .padding(10)
//            .contentShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .glassEffect()
//        .background(
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .fill(.ultraThinMaterial)
//        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(priorityColor.opacity(0.8), lineWidth: 0.2)
        )
        .shadow(color: priorityColor.opacity(0.8), radius: 5, x: 0, y: 0)
    }
}

struct PriorityCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatefulPreviewWrapper(false) { isOn in
                PriorityCell(isSelected: true)//isOn
                    .padding()
                    .previewLayout(.sizeThatFits)
            }
            .preferredColorScheme(.light)

            StatefulPreviewWrapper(true) { isOn in
                PriorityCell(title: "Urgen and Important", isSelected: true)//isOn)
                    .padding()
                    .previewLayout(.sizeThatFits)
            }
            .preferredColorScheme(.dark)
        }
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
