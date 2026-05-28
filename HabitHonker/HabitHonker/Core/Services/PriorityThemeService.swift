//
//  PriorityThemeService.swift
//  HabitHonker
//

import SwiftUI

struct PriorityThemeService: PriorityThemeServiceProtocol {
    private let store: UserDefaultsStore

    init(store: UserDefaultsStore = .shared) {
        self.store = store
    }

    func loadColors() async -> [Color] {
        await store.loadColors()
    }

    func loadTitles() async -> [String] {
        await store.loadTitles()
    }

    func setColor(_ color: Color, at index: Int) async {
        await store.setColor(color, at: index)
    }

    func setTitle(_ title: String, for priority: PriorityEisenhower) async {
        await store.setTitle(title, for: priority)
    }

    func setColors(_ colors: [Color]) async {
        await store.setColors(colors)
    }

    func setTitles(_ titles: [String]) async {
        await store.setTitles(titles)
    }

    func resetToDefaults() async {
        await store.resetToDefaults()
    }
}
