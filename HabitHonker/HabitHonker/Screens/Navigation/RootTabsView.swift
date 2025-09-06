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
}

struct RootTabsView: View {
    @StateObject private var viewModel: HabitListViewModel

    init(container: ModelContainer) {
        _viewModel = StateObject(
            wrappedValue: HabitListViewModel(
                repo: HabitsRepositorySwiftData(container: container)
            )
        )
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
            
            StaisticsView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text(Constants.statistic)
                }
        }
        .environmentObject(viewModel)
        .task { await viewModel.loadIfNeeded() }
    }
}

extension RootTabsView {
    enum Constants {
        static let list = "List"
        static let priority = "Priority"
        static let statistic = "Statistic"
    }
}

