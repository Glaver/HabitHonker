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
    private let container: ModelContainer = {
        let schema = Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self])
        return try! ModelContainer(for: schema)
    }()

    var body: some Scene {
        WindowGroup {
            RootTabsView(container: container)
                .modelContainer(container)
        }
    }
}
