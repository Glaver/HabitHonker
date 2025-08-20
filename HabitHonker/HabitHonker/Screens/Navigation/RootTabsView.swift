//
//  Nav.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/9/25.
//

import SwiftUI
import SwiftData

// MARK: - Routes for value-based navigation
enum Route: Hashable, Equatable {
    case detailHabit(UUID)
    case addNewHabit
}

struct RootTabsView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            HabitListView(makeViewModel: {
                let container = modelContext.container
                return HabitListViewModel(repo: HabitsRepositorySwiftData(container: container))
            })
            .tabItem {
                Image(systemName: "line.3.horizontal")
                Text(Constants.list)
            }
            
            Text(Constants.priority)
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(Constants.priority)
                }
        }
    }
}

extension RootTabsView {
    enum Constants {
        static let list = "List"
        static let priority = "Priority"
    }
}
