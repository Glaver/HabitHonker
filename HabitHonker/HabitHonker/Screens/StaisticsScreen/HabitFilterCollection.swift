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
    
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.filterItems.indices, id: \.self) { index in
                    let item = viewModel.filterItems[index]
                    let selected = viewModel.isSelected(item)
                    
                    Button(action: { viewModel.toggle(item) }) {
                        HStack(spacing: 6) {
                            Image(item.icon ?? "empty_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .background(selected ? item.color.opacity(0.8) : item.color.opacity(0.5))
                        .clipShape(Capsule())
                        .glassEffect()
                        .shadow(color: selected ? item.color.opacity(0.9) : .clear, radius: 5, x: 2, y: 2)
                    }
                    .padding(.leading, index == 0 ? 8 : 0)
                    .buttonStyle(.plain)
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
                color: habit.priority.color, // TODO: Refactro when I will add color picker
                isAll: false
            )
            
            output.append(model)
        }
        
        return output
    }
}
