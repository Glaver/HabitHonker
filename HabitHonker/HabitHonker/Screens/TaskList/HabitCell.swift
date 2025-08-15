//
//  HabitCell.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/9/25.
//


import SwiftUI
import SwiftData

struct HabitCell: View {
    let item: ListHabitItem
    private var isCompletedToday: Bool { item.isCompletedToday }
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(isCompletedToday ? item.priority.color.opacity(0.05) : item.priority.color.opacity(0.7))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
                    .frame(width: 60, height: 60)
                    .glassEffect()
                
                Image(item.icon ?? "empty_icon")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                        Spacer()
                        if item.type == .repeating {
                            Image(systemName: "infinity")
                                .foregroundColor(.black)
                                .padding(.trailing, 15)
                        }
                    }
                }
                Text(item.priority.text)
                    .font(.caption)
                    .foregroundColor(isCompletedToday ? .gray :.secondary)
                
                if item.isNotificationActivated  {
                    Spacer()
                    
                    HStack {
                        Text("Remind me at")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(.white.opacity(0.1))
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
                                .frame(width: 98, height: 31)
                                .glassEffect()
                            Text(item.dueDate.getTimeFrom())
                                .font(.subheadline)
                                .padding(.horizontal, 5)
                        }
                    }
                    .glassEffect()
                }
            }
            .padding(.leading, 5)
            .padding(.trailing, 10)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 10)
        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 15, trailing: 10))
        .frame(maxWidth: .infinity) // fill full width
        .listRowInsets(EdgeInsets()) // remove extra padding
        .listRowSeparator(.hidden)   // hide divider
        .glassEffect()
    }
}
