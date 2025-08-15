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
            ContentView(makeViewModel: {
                let container = modelContext.container
                return HabitListViewModel(repo: HabitsRepositorySwiftData(container: container))
            })
            .tabItem {
                Image(systemName: "line.3.horizontal")
                Text("List")
            }
            
            Text("Priority")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Priority")
                }
            
            Text("Statistics")
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Statistics")
                }
            
            Text("Account")
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Account")
                }
        }
    }
}
