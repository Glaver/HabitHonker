//
//  Nav.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/9/25.
//

import SwiftUI

// MARK: - Routes for value-based navigation
enum Route: Hashable {
    case detailHabit
    case addNewHabit
}

struct RootTabsView: View {
    var body: some View {
        TabView {
            ContentView() // Tab 1 with NavigationStack + pushes
                .tabItem {
                    Image(systemName: "line.3.horizontal")
                    Text("List")
                }
            
            Text("Priority")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Priority")
                }
            
            Text("Staistic")
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Staistic")
                }
            
            Text("Account")
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Account")
                }
        }
    }
}
