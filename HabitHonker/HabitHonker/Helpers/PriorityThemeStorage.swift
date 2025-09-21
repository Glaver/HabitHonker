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
        // UIKit bridge is available on iOS — DO NOT override UIColor(Color) yourself.
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
        #else
        return RGBA(r: 0, g: 0, b: 0, a: 1)
        #endif
    }
}

enum PriorityThemeKeys {
    static let colors = "priority_colors_v1"
    static let titles = "priority_titles_v1"
}

// Default titles/colors (match your enum defaults)
private let defaultTitles: [String] = [
    PriorityEisenhower.Constants.importantAndUrgent,
    PriorityEisenhower.Constants.urgentButNotImportant,
    PriorityEisenhower.Constants.importantButNotUrgent,
    PriorityEisenhower.Constants.notUrgentAndNotImportant
]
private let defaultColors: [Color] = [
    .red, .yellow, .blue, .green
]

// Pre-encoded defaults for @AppStorage fallbacks
let defaultTitlesBlob: Data = (try? JSONEncoder().encode(defaultTitles)) ?? Data()
let defaultColorsBlob: Data = (try? JSONEncoder().encode(defaultColors.map { $0.rgba() })) ?? Data()

// Decode helpers
func decodeTitles(_ data: Data) -> [String] {
    (try? JSONDecoder().decode([String].self, from: data)) ?? defaultTitles
}
func decodeColors(_ data: Data) -> [Color] {
    let payload = (try? JSONDecoder().decode([RGBA].self, from: data)) ?? defaultColors.map { $0.rgba() }
    return payload.map(Color.init)
}
func encodeTitles(_ titles: [String]) -> Data {
    (try? JSONEncoder().encode(titles)) ?? defaultTitlesBlob
}
func encodeColors(_ colors: [Color]) -> Data {
    (try? JSONEncoder().encode(colors.map { $0.rgba() })) ?? defaultColorsBlob
}

// Handy wrapper view to read the current theme reactively anywhere
struct PriorityThemeReader<Content: View>: View {
    @AppStorage(PriorityThemeKeys.colors) private var colorsBlob: Data = defaultColorsBlob
    @AppStorage(PriorityThemeKeys.titles) private var titlesBlob: Data = defaultTitlesBlob
    var content: (_ colors: [Color], _ titles: [String]) -> Content

    var body: some View {
        content(decodeColors(colorsBlob), decodeTitles(titlesBlob))
    }
}

// Small index helper
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
