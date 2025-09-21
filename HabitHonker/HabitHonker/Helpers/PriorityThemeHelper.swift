//
//  AppStorage.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/20/25.
//
// PriorityThemeStorage.swift

import SwiftUI


// Codable color payload
struct RGBA: Codable, Equatable {
    var r: Double, g: Double, b: Double, a: Double
}
extension Color {
    init(_ rgba: RGBA) {
        self = Color(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
    func rgba() -> RGBA {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(r: .init(r), g: .init(g), b: .init(b), a: .init(a))
    }
}

enum PriorityThemeKeys {
    static let colors = "priority_colors_v1"
    static let titles = "priority_titles_v1"
}

private let defaultTitles: [String] = [
    PriorityEisenhower.Constants.importantAndUrgent,
    PriorityEisenhower.Constants.urgentButNotImportant,
    PriorityEisenhower.Constants.importantButNotUrgent,
    PriorityEisenhower.Constants.notUrgentAndNotImportant
]
private let defaultColors: [Color] = [.red, .yellow, .blue, .green]

let defaultTitlesData: Data = (try? JSONEncoder().encode(defaultTitles)) ?? Data()
let defaultColorsData: Data = (try? JSONEncoder().encode(defaultColors.map { $0.rgba() })) ?? Data()

func decodeTitles(_ data: Data) -> [String] {
    (try? JSONDecoder().decode([String].self, from: data)) ?? defaultTitles
}
func decodeColors(_ data: Data) -> [Color] {
    let payload = (try? JSONDecoder().decode([RGBA].self, from: data)) ?? defaultColors.map { $0.rgba() }
    return payload.map(Color.init)
}
func encodeTitles(_ titles: [String]) -> Data {
    (try? JSONEncoder().encode(titles)) ?? defaultTitlesData
}
func encodeColors(_ colors: [Color]) -> Data {
    (try? JSONEncoder().encode(colors.map { $0.rgba() })) ?? defaultColorsData
}
extension PriorityEisenhower: Hashable {}
extension PriorityEisenhower {
    // Fixed UI order (TL, TR, BL, BR) — adjust to your layout
    static let uiOrder: [PriorityEisenhower] = [
        .importantAndUrgent,
        .urgentButNotImportant,
        .importantButNotUrgent,
        .notUrgentAndNotImportant
    ]
}
extension PriorityEisenhower {
    var index: Int {
        switch self {
        case .importantAndUrgent:       return 0
        case .urgentButNotImportant:    return 1
        case .importantButNotUrgent:    return 2
        case .notUrgentAndNotImportant: return 3
        }
    }
}
