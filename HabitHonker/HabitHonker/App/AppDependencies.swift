//
//  AppDependencies.swift
//  HabitHonker
//

import SwiftData

struct AppDependencies {
    let habitRepository: HabitRepositoryProtocol
    let habitService: HabitServiceProtocol
    let priorityThemeService: PriorityThemeServiceProtocol
    let backgroundService: BackgroundServiceProtocol
    let habitEvents: HabitEventsPublishing

    static func make(container: ModelContainer) -> AppDependencies {
        let habitEvents = HabitEventCenter()
        let habitRepository = SwiftDataHabitRepository(container: container)
        let habitService = HabitService(repository: habitRepository,
                                        habitEvents: habitEvents)

        return AppDependencies(
            habitRepository: habitRepository,
            habitService: habitService,
            priorityThemeService: PriorityThemeService(),
            backgroundService: BackgroundService(),
            habitEvents: habitEvents
        )
    }
}
