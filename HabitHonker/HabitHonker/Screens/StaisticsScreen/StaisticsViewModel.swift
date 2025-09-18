//
//  StaisticsViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import Combine
import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var habitPresetIDs: [UUID] = []
    
    @Published private(set) var selected: Set<UUID> = []
    @Published var items: [HabitModel] = []
    @Published var filterItems: [HabitFilterCollectionModel] = [] {
        didSet { pruneSelectionIfNeeded() }
    }
    
    @Published var months: [MonthSection] = []
    
    private let builder = CalendarBuilder()
    
    func reloadStatistic(anchor: Date = Date()) {
        builder.updateHabits(items)
        let todayKey = Calendar.current.startOfDay(for: Date())
        let month = builder.makeMonth(for: Date())
        months = builder.makeYear(for: anchor)
    }
    
    
    let maxRegularSelections = 4
    
    private let allUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    
    private var allID: UUID { filterItems.first?.id ?? UUID() }
    
    @Published private(set) var error: Error?
    @Published private(set) var isLoading = false
    
    let repo: HabitsRepositorySwiftData

    init(repo: HabitsRepositorySwiftData) {
        self.repo = repo
    }

    func loadPresetHabits() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let preset = try await repo.fetchStatisticsPreset() else {
                self.filterItems = makeListWithAll([])
                self.items = []
                return
            }

            habitPresetIDs = preset.habitIDs
            
            var resolved: [HabitModel] = []
            
            for id in habitPresetIDs {
                // Try active first
                if let habit = try await repo.fetch(id: id) {
                    resolved.append(habit)
                }
                // If not found, try deleted
                else if let deleted = try await repo.fetchDeleted(id: id) {
                    resolved.append(deleted)
                }
                // If not found at all, skip silently (or log)
            }
            
            self.items = resolved
            self.filterItems = makeListWithAll(HabitFilterCollectionModel.mapFrom(resolved))
//            print("StatisticsView ID of habits in preset:\(habitPresetIDs)")
        } catch {
            self.error = error
//            print("❌ Failed to load habits from preset: \(error)")
        }
    }

    func isSelected(_ item: HabitFilterCollectionModel) -> Bool {
        selected.contains(item.id)
    }

    var canSelectMore: Bool {
        selected.subtracting([allID]).count < maxRegularSelections
    }

    func toggle(_ item: HabitFilterCollectionModel) {
        guard let all = filterItems.first else { return }

        if item.isAll {
            // If already fully selected, clear all; otherwise select all
            let allRegularIDs = Set(filterItems.dropFirst().map(\.id))
            if selected.isSuperset(of: allRegularIDs) && selected.contains(all.id) {
                selected.removeAll()
            } else {
                selected = Set(filterItems.map(\.id))
            }
            return
        }

        // Toggle a regular item with max-4 enforcement
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            // Enforce max regular selections
            if !canSelectMore { return }
            selected.insert(item.id)
        }

        // Maintain "All" state consistency
        let allRegularIDs = Set(filterItems.dropFirst().map(\.id))
        if selected.isSuperset(of: allRegularIDs) {
            selected.insert(all.id)
        } else {
            selected.remove(all.id)
        }
    }
    
    private func makeListWithAll(_ regulars: [HabitFilterCollectionModel]) -> [HabitFilterCollectionModel] {
        // Ensure your model can represent "All"
        let all = HabitFilterCollectionModel(
            id: allUUID,
            title: "All",
            icon: "empty_icon",
            color: .gray, // adapt to your type
            isAll: true
        )
        
        // Choose which 4 to show; customize sorting if needed
        let top4 = Array(regulars.prefix(maxRegularSelections))
        return [all] + top4
    }
    
    /// Keeps `selected` consistent when `items` change (e.g., reload or cap to 4).
    private func pruneSelectionIfNeeded() {
        let validIDs = Set(filterItems.map(\.id))
        if !selected.isSubset(of: validIDs) {
            selected = selected.intersection(validIDs)
        }
        // If all 4 regular are selected, re-sync "All"
        if let all = filterItems.first {
            let allRegular = Set(filterItems.dropFirst().map(\.id))
            if selected.isSuperset(of: allRegular) {
                selected.insert(all.id)
            } else {
                selected.remove(all.id)
            }
        }
    }
}
