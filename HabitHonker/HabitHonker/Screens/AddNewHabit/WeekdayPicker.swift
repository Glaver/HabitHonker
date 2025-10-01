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
    var color: Color = .accentColor
    @Environment(\.colorScheme) var scheme

    private var orderedWeekdays: [Weekday] {
        // Respect the user’s locale firstWeekday in ordering
        let start = calendar.firstWeekday // 1...7
        return (0..<7).compactMap { Weekday(rawValue: ((start - 1 + $0) % 7) + 1) }
    }

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(orderedWeekdays, id: \.rawValue) { day in
                let isOn = selection.contains(day)

                Text(day.shortSymbol.uppercased())
                    .lineLimit(1)
                    .foregroundColor(.primary.opacity(1))
                    .font(.caption).monospaced()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(isOn ? color.opacity(scheme == .dark ? 0.8 : 0.3) : Color("cellContentColor")))
                    .onTapGesture {
                        if isOn { selection.remove(day) } else { selection.insert(day) }
                    }
                    .accessibilityLabel(Text(day.shortSymbol))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .glassEffect()
                    .shadow(color: isOn ? color.opacity(Color.opacityForSheme(scheme)) : .black.opacity(0.2), radius: 5, x: 2, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
