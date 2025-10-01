//
//  HabitHonkerApp.swift
//  HabitHonker
//
//  Created by Vladyslav on 7/30/25.
//

import SwiftUI
import SwiftData

@main
struct HabitHonkerApp: App {
    @AppStorage("appearance") private var appearanceRaw: String = HonkerColorSchema.auto.rawValue
    private var appearance: HonkerColorSchema { HonkerColorSchema(rawValue: appearanceRaw) ?? .auto }

    @State private var container: ModelContainer?

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootTabsView(container: container)
                        .modelContainer(container)
                } else {
                    // ultra-light placeholder; system splash stays vivid
                    Color(.systemBackground)
                        .ignoresSafeArea()
                }
            }
            .preferredColorScheme(appearance.colorScheme)
            .task(priority: .userInitiated) {
                if container == nil {
                    container = try? ModelContainer(for: Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self]))
                }
            }
        }
    }
}

