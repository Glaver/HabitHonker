//
//  AppDependencies.swift
//  HabitHonker
//

import SwiftData

struct AppDependencies {
    let behaviorTransactionService: any BehaviorTransactionServiceProtocol
    let habitRepository: HabitRepositoryProtocol
    let habitService: HabitServiceProtocol
    let statisticsService: StatisticsServiceProtocol
    let priorityThemeService: PriorityThemeServiceProtocol
    let backgroundService: BackgroundServiceProtocol
    let habitEvents: HabitEventsPublishing
    let featureFlags: FeatureFlags

    static func make(container: ModelContainer,
                     featureFlags: FeatureFlags = .defaults) -> AppDependencies {
        let habitEvents = HabitEventCenter()
        let swiftDataRepository = HabitsRepositorySwiftData(container: container)
        let gamification = GamificationService(rewardCalculator: RewardCalculator(), levelCalculator: LevelCalculator())
        let transactionRepository = SwiftDataBehaviorTransactionRepository(repository: swiftDataRepository,
                                                                           gamificationService: gamification)
        let transactionService = BehaviorTransactionService(repository: transactionRepository)
        let habitRepository = SwiftDataHabitRepository(repository: swiftDataRepository)
        let habitService = HabitService(repository: habitRepository,
                                        habitEvents: habitEvents)
        let statisticsService = StatisticsService(habitRepository: habitRepository)

        return AppDependencies(
            behaviorTransactionService: transactionService,
            habitRepository: habitRepository,
            habitService: habitService,
            statisticsService: statisticsService,
            priorityThemeService: PriorityThemeService(),
            backgroundService: BackgroundService(),
            habitEvents: habitEvents,
            featureFlags: featureFlags
        )
    }
}
