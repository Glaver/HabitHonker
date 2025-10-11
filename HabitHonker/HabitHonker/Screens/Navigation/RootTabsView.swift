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
    @StateObject private var statisticsViewModel: StatisticsViewModel
    
    private let container: ModelContainer
    private let repo: HabitsRepositorySwiftData
    
    init(container: ModelContainer) {
        self.container = container
        
        let localRepo = HabitsRepositorySwiftData(container: container)
        let defaults = UserDefaultsStore.shared
        
        _listViewModel = StateObject(wrappedValue: HabitListViewModel(usedDefaultsRepo: defaults, repo: localRepo))
        _statisticsViewModel = StateObject(wrappedValue: StatisticsViewModel(repo: localRepo))
        
        self.repo = localRepo
    }
    
    var body: some View {
        TabView {
            HabitListView()
                .tabItem {
                    Image(systemName: "line.3.horizontal")
                    Text(Constants.list)
                }
            
            PriorityMatrixView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(Constants.priority)
                }
            
            StaisticsView(viewModel: statisticsViewModel)
                .tabItem {
                    Image(systemName: "calendar")
                    Text(Constants.statistic)
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(Constants.settings)
                }
        }
        .environmentObject(listViewModel)
        .task(priority: .userInitiated) {
            // Run all three in parallel
            async let auth: Void = listViewModel.onAppLaunch()
            async let theme: Void = listViewModel.reloadTheme()
            async let load:  Void = listViewModel.loadIfNeeded()
            _ = await (auth, theme, load)
        }
        .onAppear {
            listViewModel.primeBackgroundFromDisk()
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

