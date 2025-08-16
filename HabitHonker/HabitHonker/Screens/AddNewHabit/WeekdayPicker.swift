//
//  WeekdayPicker.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/10/25.
//


import SwiftUI
import SwiftData

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    var calendar: Calendar = .current

    private var orderedWeekdays: [Weekday] {
        // Respect the user’s locale firstWeekday in ordering
        let start = calendar.firstWeekday // 1...7
        return (0..<7).compactMap { Weekday(rawValue: ((start - 1 + $0) % 7) + 1) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(orderedWeekdays, id: \.rawValue) { day in
                let isOn = selection.contains(day)
                Text(day.shortSymbol.uppercased())
                    .lineLimit(1)
                    .font(.caption).monospaced()
                    .padding(.vertical, 15)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(isOn ? Color.accentColor.opacity(0.05) : .clear))
                    .onTapGesture {
                        if isOn { selection.remove(day) } else { selection.insert(day) }
                    }
                    .accessibilityLabel(Text(day.shortSymbol))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .glassEffect()
                    .shadow(color: isOn ? Color.accentColor.opacity(0.3) : .clear, radius: 5, x: 0, y: 0)
            }
        }
    }
}
