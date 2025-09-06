//
//  DayItem.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

// MARK: - Models

struct Pill: Identifiable, Hashable {
    let id = UUID()
    let color: Color
}

struct DayItem: Identifiable, Hashable {
    let id: UUID
    let date: Date?
    let inCurrentMonth: Bool
    let isToday: Bool
    let pills: [Pill]
    let isEmpty: Bool
    
    static let blank = DayItem(id: UUID(), date: nil, inCurrentMonth: false, isToday: false, pills: [], isEmpty: true)
}

struct MonthSection: Identifiable {
    let id = UUID()
    let monthDate: Date // any date inside that month
    let title: String   // "August 2025"
    let days: [DayItem] // padded to a multiple of 7
}
