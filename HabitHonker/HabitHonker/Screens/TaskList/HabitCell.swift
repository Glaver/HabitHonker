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
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(item.iconColor?.opacity(0.6) ?? Color.clear)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
                    .frame(width: 60, height: 60)
                    .glassEffect()
                
                Image(systemName: item.icon)
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
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.gray)
                                .padding(.trailing, 15)
                        }
                    }
                }
                Text(item.priority.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let remindTime = item.notificationActivated {
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
                            Text("8:00 AM")
                                .font(.subheadline)
                                .padding(.horizontal, 13)
                        }
                    }
//                    .background(.ultraThinMaterial)
                    
//                    .clipShape(Capsule())
                    
                    .glassEffect()
                    
                }
                
            }
            .padding(.leading, 5)
            .padding(.trailing, 10)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 10)
//        .background(.ultraThinMaterial)
        .cornerRadius(26)
        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 15, trailing: 10))
//        .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
        .frame(maxWidth: .infinity) // fill full width
        .listRowInsets(EdgeInsets()) // remove extra padding
        .listRowSeparator(.hidden)   // hide divider
        .glassEffect()
    }
}
