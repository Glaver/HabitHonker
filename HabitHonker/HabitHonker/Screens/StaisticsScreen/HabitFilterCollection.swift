//
//  HabitFilterCollection.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

struct HabitFilter: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let systemIcon: String
}

struct HabitFilterCollection: View {
    let filters: [HabitFilter] = [
        HabitFilter(title: "All", color: .gray.opacity(0.15), systemIcon: "diamond"),
        HabitFilter(title: "Morning water vs lime", color: .red, systemIcon: "diamond.fill"),
        HabitFilter(title: "Meditation", color: .blue, systemIcon: "diamond.fill"),
        HabitFilter(title: "Workout", color: .green, systemIcon: "diamond.fill")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    HStack(spacing: 6) {
                        Image(systemName: filter.systemIcon)
                            .font(.system(size: 12, weight: .bold))
                        Text(filter.title)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(filter.color)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    HabitFilterCollection()
}
