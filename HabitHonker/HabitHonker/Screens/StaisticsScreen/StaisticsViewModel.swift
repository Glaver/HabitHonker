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
    @Published var items: [HabitModel] = []              // all resolved habits
    @Published var filterItems: [HabitFilterCollectionModel] = []
    @Published private(set) var months: [MonthSection] = []
    @Published private(set) var selected: Set<UUID> = [] // selected filter IDs (includes "All" when appropriate)
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var calendarAnchor: Date = Date()
    
    let maxRegularSelections = 4
    private let allUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    
    private let builder = CalendarBuilder()
    let repo: HabitsRepositorySwiftData

    
    private var bag = Set<AnyCancellable>()

    // MARK: - Init
    init(repo: HabitsRepositorySwiftData) {
        self.repo = repo
        setupPipelines()
    }

    // MARK: - Public API
    
    func reloadStatistic(anchor: Date = Date()) {
        calendarAnchor = anchor   // triggers the pipeline above
    }
    
    func loadPresetHabits() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let preset = try await repo.fetchStatisticsPreset() else {
                self.items = []
                self.filterItems = makeListWithAll([])
                self.selected = []
                return
            }

            // Resolve active or deleted habits for the preset
            var resolved: [HabitModel] = []
            for id in preset.habitIDs {
                if let habit = try await repo.fetch(id: id) { resolved.append(habit) }
                else if let deleted = try await repo.fetchDeleted(id: id) { resolved.append(deleted) }
            }

            // Update source lists (this will flow through the pipelines)
            self.items = resolved
            self.filterItems = makeListWithAll(HabitFilterCollectionModel.mapFrom(resolved))

            // Default selection → “All” (and implicitly every visible regular item)
            if let all = filterItems.first { self.selected = [all.id] }
        } catch {
            self.error = error
        }
    }

    func toggle(_ item: HabitFilterCollectionModel) {
        guard let all = filterItems.first else { return }

        // Toggle ALL
        if item.isAll {
            // If already effectively "All", clear; else select "All" only
            if isAllSelected() {
                selected.removeAll()
            } else {
                selected = [all.id] // hold only "All" → means "all regulars" in the pipeline
            }
            return
        }

        // Regular items
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            // Enforce max selections (ignoring the "All" sentinel)
            let regularCount = selected.subtracting([all.id]).count
            guard regularCount < maxRegularSelections else { return }
            selected.insert(item.id)
        }

        // Keep "All" in sync
        resyncAllSentinel()
    }

    func isSelected(_ item: HabitFilterCollectionModel) -> Bool { selected.contains(item.id) }
    
    var canSelectMore: Bool {
        guard let all = filterItems.first else { return false }
        return selected.subtracting([all.id]).count < maxRegularSelections
    }

    // MARK: - PRIVATE

    /// Wire the reactive graph:
    /// items + filterItems + selected  ==> visibleHabits  ==> months
    private func setupPipelines(anchor: Date = Date()) {
        // items + filterItems + selected + calendarAnchor  ==> months
        Publishers.CombineLatest4($items, $filterItems, $selected, $calendarAnchor)
            .map { items, filters, selected, anchor -> [HabitModel] in
                guard let all = filters.first else { return [] }
                if selected.isEmpty || selected.contains(all.id) { return items }
                let picked = Set(selected)
                return items.filter { picked.contains($0.id) }
            }
            .removeDuplicates(by: { $0.map(\.id) == $1.map(\.id) })
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .handleEvents(receiveOutput: { [weak self] visibles in
                self?.builder.updateHabits(visibles)
            })
            .map { [weak self] _ in
                guard let self else { return [] }
                return self.builder.makeYear(for: self.calendarAnchor)
            }
            .receive(on: RunLoop.main)
            .assign(to: &$months)

    }

    private func makeListWithAll(_ regulars: [HabitFilterCollectionModel]) -> [HabitFilterCollectionModel] {
        let all = HabitFilterCollectionModel(
            id: allUUID, title: "All", icon: "empty_icon", color: .gray, isAll: true
        )
        let top4 = Array(regulars.prefix(maxRegularSelections))
        return [all] + top4
    }

    private func isAllSelected() -> Bool {
        guard let all = filterItems.first else { return false }
        if selected.contains(all.id) { return true }

        let allRegularIDs = Set(filterItems.dropFirst().map(\.id))
        return selected.isSuperset(of: allRegularIDs)
    }

    private func resyncAllSentinel() {
        guard let all = filterItems.first else { return }
        let allRegularIDs = Set(filterItems.dropFirst().map(\.id))
        if selected.isSuperset(of: allRegularIDs) {
            selected = [all.id] // collapse to "All" only (keeps state small)
        } else {
            selected.remove(all.id)
        }
    }
}
