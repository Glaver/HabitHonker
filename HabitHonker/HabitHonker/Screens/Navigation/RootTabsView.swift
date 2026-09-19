//
//  RootTabsView.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/9/25.
//
//

import SwiftUI
import SwiftData

// MARK: - Routes
enum Route: Hashable, Equatable {
    case detailHabit(UUID)
    case addNewHabit
    case choseHabitForStatistics
    case priorityMatrixEditor
}

struct RootTabsView: View {
    @StateObject private var listViewModel: HabitListViewModel
    @StateObject private var priorityMatrixViewModel: PriorityMatrixViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var statisticsViewModel: StatisticsViewModel
    
    private let container: ModelContainer
    
    init(container: ModelContainer, dependencies: AppDependencies? = nil) {
        self.container = container
        
        let defaults = UserDefaultsStore.shared
        let habitService: HabitServiceProtocol
        let statisticsService: StatisticsServiceProtocol
        let priorityThemeService: PriorityThemeServiceProtocol
        let backgroundService: BackgroundServiceProtocol
        let habitEvents: HabitEventsPublishing
        
        if let dependencies {
            habitService = dependencies.habitService
            statisticsService = dependencies.statisticsService
            priorityThemeService = dependencies.priorityThemeService
            backgroundService = dependencies.backgroundService
            habitEvents = dependencies.habitEvents
        } else {
            habitEvents = HabitEventCenter()
            let localRepo = HabitsRepositorySwiftData(container: container)
            let habitRepository = SwiftDataHabitRepository(repository: localRepo)
            habitService = HabitService(repository: habitRepository,
                                        habitEvents: habitEvents)
            statisticsService = StatisticsService(habitRepository: habitRepository)
            priorityThemeService = PriorityThemeService(store: defaults)
            backgroundService = BackgroundService()
        }

        _listViewModel = StateObject(wrappedValue: HabitListViewModel(habitService: habitService,
                                                                      habitEvents: habitEvents,
                                                                      priorityThemeService: priorityThemeService,
                                                                      backgroundService: backgroundService))
        _priorityMatrixViewModel = StateObject(wrappedValue: PriorityMatrixViewModel(habitService: habitService,
                                                                                    themeService: priorityThemeService,
                                                                                    habitEvents: habitEvents))
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(priorityThemeService: priorityThemeService,
                                                                         backgroundService: backgroundService))
        _statisticsViewModel = StateObject(wrappedValue: StatisticsViewModel(statisticsService: statisticsService,
                                                                             habitEvents: habitEvents))
    }
    
    var body: some View {
        TabView {
            HabitListView()
                .tabItem {
                    Image(systemName: "line.3.horizontal")
                    Text(Constants.list)
                }
            
            PriorityMatrixView(viewModel: priorityMatrixViewModel)
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(Constants.priority)
                }
            
            StaisticsView(viewModel: statisticsViewModel)
                .tabItem {
                    Image(systemName: "calendar")
                    Text(Constants.statistic)
                }
            
            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(Constants.settings)
                }
        }
        .environmentObject(listViewModel)
        .task(priority: .userInitiated) {
            // Run all three in parallel
            async let auth: Void = listViewModel.onAppLaunch()
            async let appearance: Void = listViewModel.reloadAppearanceForDisplay()
            async let load:  Void = listViewModel.loadIfNeeded()
            _ = await (auth, appearance, load)
        }
        .onAppear {
            Task.detached(priority: .utility) { [statisticsViewModel] in
                await statisticsViewModel.loadPresetHabits()
            }
        }
    }
}

extension RootTabsView {
    enum Constants {
        static let list = "List"
        static let priority = "Priority"
        static let statistic = "Statistic"
        static let settings = "Settings"
    }
}
