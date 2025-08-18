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
    private var isCompletedToday: Bool { item.isCompletedToday }
    
    var body: some View {
        GlassEffectContainer {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 23)
                        .fill(isCompletedToday ? item.priority.color.opacity(0.05) : item.priority.color.opacity(0.5))
                        .frame(width: 56)
                        .zIndex(0)
                    
                    Image(item.icon ?? "empty_icon")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .scaledToFit()
                        .foregroundColor(.black)
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
                            Text(item.priority.text)
                                .font(.caption)
                                .foregroundColor(isCompletedToday ? .gray :.secondary)
                        }
                        Spacer()
                        if item.type == .repeating {
                            Image(systemName: "infinity")
                                .foregroundColor(.black)
                                .padding(.trailing, 15)
                        }
                    }
                    
                    if item.isNotificationActivated  {
                        Spacer()
                        HStack {
                            Text("Remind me at")
                                .font(.subheadline)
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
                                    .padding(.horizontal, 5)
                                    .glassEffect()
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
