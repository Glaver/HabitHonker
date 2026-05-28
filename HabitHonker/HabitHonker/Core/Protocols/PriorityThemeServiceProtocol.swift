//
//  PriorityThemeServiceProtocol.swift
//  HabitHonker
//

import SwiftUI

protocol PriorityThemeServiceProtocol {
    func loadColors() async -> [Color]
    func loadTitles() async -> [String]
    func setColor(_ color: Color, at index: Int) async
    func setTitle(_ title: String, for priority: PriorityEisenhower) async
    func setColors(_ colors: [Color]) async
    func setTitles(_ titles: [String]) async
    func resetToDefaults() async
}
