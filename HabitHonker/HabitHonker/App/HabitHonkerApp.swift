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
    var body: some Scene {
        WindowGroup {
            RootTabsView()
        }
        .modelContainer(for: [HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self])
    }
}
