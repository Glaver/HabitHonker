//
//  HonkerColorSchema.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/23/25.
//
import SwiftUI

enum HonkerColorSchema: String, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto:  return nil     // system
        case .light: return .light
        case .dark:  return .dark
        }
    }

    var title: String {
        switch self {
        case .auto:  return "Auto"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }
}
