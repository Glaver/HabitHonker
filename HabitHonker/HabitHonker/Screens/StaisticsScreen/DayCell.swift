//
//  DayCell.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

struct DayCell: View {
    let day: DayItem
    var widthCell: CGFloat
    
    var body: some View {
        ZStack {
            if !day.isEmpty {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: widthCell)
                    .frame(height: 74)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(day.isToday ? Color.blue : Color(.tertiaryLabel),
                                          lineWidth: day.isToday ? 2 : 1)
                    )
            }
            
            VStack(spacing: 6) {
                PillStack(pills: day.pills)
                    .padding(.bottom, 2)
                    .frame(height: 44)
                Text(dayLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 74)
        .opacity(day.inCurrentMonth ? 1.0 : 0.28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }
    
    private var dayLabel: String {
        guard let date = day.date else { return "" }
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("dd.MM")
        return df.string(from: date)
    }
    
    private var accessibilityText: String {
        guard let date = day.date else { return "Empty" }
        let df = DateFormatter()
        df.dateStyle = .full
        return "\(df.string(from: date)). \(day.pills.count) items."
    }
}
