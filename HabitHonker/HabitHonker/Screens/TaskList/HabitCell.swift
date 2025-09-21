//
//  HabitCell.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/9/25.
//


import SwiftUI
import SwiftData

struct HabitCell: View {
    let item: HabitModel
    let pillColor: Color
//    var pillColor: Color { priorityColor[item.priority.index] }
    private var isCompletedToday: Bool { item.isCompletedToday }
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        GlassEffectContainer {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 23)
                        .fill(isCompletedToday ? pillColor.opacity(0.05) : pillColor.opacity(Color.opacityForSheme(scheme)))
                        .frame(width: 56)
                        .zIndex(0)
                    
                    Image(item.icon ?? "empty_icon")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .scaledToFit()
                        .foregroundColor(.primary.opacity(1))
                        .zIndex(1)
                        .padding(.vertical, 10)
                }
                .glassEffect(isCompletedToday ? .clear : .regular, in: RoundedRectangle(cornerRadius: 23))
                .frame(maxHeight:.infinity)
                
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading,spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(.primary.opacity(isCompletedToday ? 0.5 : 1))
                            Text(item.priority.text)
                                .font(.caption)
                                .foregroundColor(.primary.opacity(isCompletedToday ? 0.5 : 1))
                        }
                        Spacer()
                        if item.type == .repeating {
                            Image(systemName: "infinity")
                                .foregroundColor(.primary.opacity(1))
                                .padding(.trailing, 15)
                        }
                    }
                    
                    if item.isNotificationActivated  {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
                                .frame(height: 31)
                                
                            HStack {
                                Text(Constants.remindMeAt)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                Spacer()
                                ZStack {
                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                        .fill(.white.opacity(0.3))
                                        .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
                                        .frame(width: 98, height: 31)
                                        .glassEffect()
                                    Text(item.dueDate.getTimeFrom())
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 5)
                                        .glassEffect()
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 5)
                .padding(.trailing, 10)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .glassEffect(isCompletedToday ? .clear : .regular, in: RoundedRectangle(cornerRadius: 25))
    }
}

extension HabitCell {
    enum Constants {
        static let remindMeAt = "Remind me at"
    }
}
