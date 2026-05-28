//
//  AppCoordinator.swift
//  HabitHonker
//

import SwiftUI

enum AppTab: Hashable {
    case habits
    case priority
    case statistics
    case settings
}

@MainActor
final class AppCoordinator: ObservableObject {
    let dependencies: AppDependencies
    @Published var selectedTab: AppTab = .habits

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }
}
