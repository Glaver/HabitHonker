//
//  HabitFilterCollection.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//HabitFilterCollection

import SwiftUI

// MARK: - Model

struct HabitFilterCollectionModel: Identifiable, Hashable {
    let id: UUID
    let title: String
    let icon: String?
    let color: Color
    let isAll: Bool
}

// MARK: - View

struct HabitFilterCollection: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    // Adaptive grid feels like a “collection” of chips
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.items) { item in
                    let selected = viewModel.isSelected(item)
                    let disabled = !selected && !item.isAll && !viewModel.canSelectMore
                    
                    Button(action: { viewModel.toggle(item) }) {
                        HStack(spacing: 6) {
                            Image(item.icon ?? "empty_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .foregroundColor(.white.opacity(disabled ? 0.6 : 1.0))
                        
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .background(
                            (selected ? item.color.opacity(0.8) : item.color.opacity(0.5))
                                .saturation(disabled ? 0.2 : 1.0)
                        )
                        .clipShape(Capsule())
                        .glassEffect()
                        .shadow(color: selected ? item.color.opacity(0.8) : .clear, radius: 5, x: 1, y: 1)
                    }
                    .padding(.leading, item.isAll ? 8 : 0)
                    .buttonStyle(.plain)
                    .disabled(disabled)
                }
            }
            .padding(.bottom, 14)
        }
        .background(.clear)
        
    }
    
}

// MARK: - Mapper

extension HabitFilterCollectionModel {
    static func mapFrom(_ habits: [HabitModel]) -> [HabitFilterCollectionModel] {
        var output: [HabitFilterCollectionModel] = []
        
        habits.forEach { habit in
            let model = HabitFilterCollectionModel(
                id: habit.id,
                title: habit.title,
                icon: habit.icon,
                color: habit.priority.color, // TODO: Refactro when I will add color
                isAll: false
            )
            
            output.append(model)
        }
        
        return output
    }
}
// MARK: - Example usage / Preview

//struct HabitMultiPicker_Previews: PreviewProvider {
//    static var sampleItems: [HabitFilterCollectionModel] = {
//        let all = HabitFilterCollectionModel(id: UUID(), title: "All", icon: "empty_icon", color: .gray, isAll: true)
//        let a = HabitFilterCollectionModel(id: UUID(), title: "Health", icon: "trash", color: .pink, isAll: false)
//        let b = HabitFilterCollectionModel(id: UUID(), title: "Focus", icon: "brain.head.profile", color: .purple, isAll: false)
//        let c = HabitFilterCollectionModel(id: UUID(), title: "Work", icon: "briefcase.fill", color: .blue, isAll: false)
//        let d = HabitFilterCollectionModel(id: UUID(), title: "Home", icon: "house.fill", color: .green, isAll: false)
//        return [all, a, b, c, d] // All must be first
//    }()
//
//    static var previews: some View {
//        HabitFilterCollection(viewModel: StatisticsViewModel())
//            .padding()
//            .background(Color.black)
//            .previewLayout(.sizeThatFits)
//    }
//}
