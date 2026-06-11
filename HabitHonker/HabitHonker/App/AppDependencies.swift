//
//  AppDependencies.swift
//  HabitHonker
//

import SwiftData

struct AppDependencies {
    let habitRepository: HabitRepositoryProtocol
    let habitService: HabitServiceProtocol
    let statisticsService: StatisticsServiceProtocol
    let priorityThemeService: PriorityThemeServiceProtocol
    let backgroundService: BackgroundServiceProtocol
    let habitEvents: HabitEventsPublishing

    static func make(container: ModelContainer) -> AppDependencies {
        let habitEvents = HabitEventCenter()
        let swiftDataRepository = HabitsRepositorySwiftData(container: container)
        let habitRepository = SwiftDataHabitRepository(repository: swiftDataRepository)
        let habitService = HabitService(repository: habitRepository,
                                        habitEvents: habitEvents)
        let statisticsService = StatisticsService(habitRepository: habitRepository)

        return AppDependencies(
            habitRepository: habitRepository,
            habitService: habitService,
            statisticsService: statisticsService,
            priorityThemeService: PriorityThemeService(),
            backgroundService: BackgroundService(),
            habitEvents: habitEvents
        )
    }
}
