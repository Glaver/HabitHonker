////
////  RepositoryUserDefaults.swift
////  HabitHonker
////
////  Created by Vladyslav on 9/20/25.
////

// PriorityThemeRepository.swift
import SwiftUI

actor UserDefaultsStore {
    static let shared = UserDefaultsStore()

    private let ud: UserDefaults
    private let colorsKey = PriorityThemeKeys.colors
    private let titlesKey = PriorityThemeKeys.titles

    init(userDefaults: UserDefaults = .standard) {
        self.ud = userDefaults
    }

    // Reads
    func loadColors() -> [Color] {
        decodeColors(ud.data(forKey: colorsKey) ?? defaultColorsData)
    }
    func loadTitles() -> [String] {
        decodeTitles(ud.data(forKey: titlesKey) ?? defaultTitlesData)
    }

    // Writes (persist immediately)
    func setColor(_ color: Color, at index: Int) {
        var arr = loadColors()
        guard arr.indices.contains(index) else { return }
        arr[index] = color
        ud.set(encodeColors(arr), forKey: colorsKey)
    }
    func setTitle(_ title: String, for prio: PriorityEisenhower) {
        var arr = loadTitles()
        arr[prio.index] = title
        ud.set(encodeTitles(arr), forKey: titlesKey)
    }

    // Utilities
    func resetToDefaults() {
        ud.set(defaultColorsData, forKey: colorsKey)
        ud.set(defaultTitlesData, forKey: titlesKey)
    }
}
// MARK: - Array writes
extension UserDefaultsStore {
    func setColors(_ colors: [Color]) {
        ud.set(encodeColors(colors), forKey: colorsKey)
    }
    
    func setTitles(_ titles: [String]) {
        ud.set(encodeTitles(titles), forKey: titlesKey)
    }
}
