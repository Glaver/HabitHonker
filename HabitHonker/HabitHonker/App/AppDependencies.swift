//
//  AppDependencies.swift
//  HabitHonker
//

import SwiftData

struct AppDependencies {
    /// Durability of the store behind `container`, decided by the composition root that built it.
    /// The enrollment service's durability gate reads it (Phase 4E). It stays exposed for
    /// reconciliation and Phase 5 routing, and constructing the graph has no gamification side effects.
    let storageDurability: StorageDurabilityState
    let behaviorTransactionService: any BehaviorTransactionServiceProtocol
    /// Phase 4E: the explicit enrollment command for this container's store. It is built here and
    /// never called here: constructing the graph creates no profile and no baseline revision.
    let gamificationEnrollmentService: any GamificationEnrollmentServicing
    let habitRepository: HabitRepositoryProtocol
    let habitService: HabitServiceProtocol
    let statisticsService: StatisticsServiceProtocol
    let priorityThemeService: PriorityThemeServiceProtocol
    let backgroundService: BackgroundServiceProtocol
    let habitEvents: HabitEventsPublishing
    let featureFlags: FeatureFlags

    /// Builds a graph scoped to exactly this container: a new container always gets a new graph.
    static func make(container: ModelContainer,
                     storageDurability: StorageDurabilityState,
                     featureFlags: FeatureFlags = .defaults) -> AppDependencies {
        let habitEvents = HabitEventCenter()
        // Phase 4B: schedule-revision planning and normal revision identity, injected into the
        // one container-scoped actor that owns every SwiftData write.
        let swiftDataRepository = HabitsRepositorySwiftData(container: container,
                                                            scheduleRevisionPlanner: BehaviorScheduleRevisionPlanner(),
                                                            scheduleRevisionIDs: BehaviorScheduleRevisionIDProviderV1())
        let gamification = GamificationService(rewardCalculator: RewardCalculator(), levelCalculator: LevelCalculator())
        let transactionRepository = SwiftDataBehaviorTransactionRepository(repository: swiftDataRepository,
                                                                           gamificationService: gamification)
        let transactionService = BehaviorTransactionService(repository: transactionRepository)
        // Phase 4E: enrollment writes through the same container-scoped actor; ephemeral storage is
        // refused by the service's durability gate.
        let enrollmentService = GamificationEnrollmentService(
            repository: SwiftDataGamificationEnrollmentRepository(repository: swiftDataRepository),
            storageDurability: storageDurability)
        let habitRepository = SwiftDataHabitRepository(repository: swiftDataRepository)
        let habitService = HabitService(repository: habitRepository,
                                        habitEvents: habitEvents)
        let statisticsService = StatisticsService(habitRepository: habitRepository)

        return AppDependencies(
            storageDurability: storageDurability,
            behaviorTransactionService: transactionService,
            gamificationEnrollmentService: enrollmentService,
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
