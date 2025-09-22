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
    @Published private(set) var selected: Set<UUID> = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var calendarAnchor: Date = Date()
    @Published private var isPriming = false
    
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
                self.filterItems = []
                self.selected = []
                return
            }

            var resolved: [HabitModel] = []
            for id in preset.habitIDs {
                if let habit = try await repo.fetch(id: id) { resolved.append(habit) }
                else if let deleted = try await repo.fetchDeleted(id: id) { resolved.append(deleted) }
            }
            
            await MainActor.run {
                self.isPriming = true
                let filters = HabitFilterCollectionModel.mapFrom(resolved)
                let sel = Set(filters.map { $0.id })
                self.items = resolved
                self.filterItems = filters
                self.selected = sel
                self.isPriming = false
            }
        } catch {
            self.error = error
        }
    }

    func toggle(_ item: HabitFilterCollectionModel) {
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            guard selected.count < maxRegularSelections else { return }
            selected.insert(item.id)
        }
    }

    func isSelected(_ item: HabitFilterCollectionModel) -> Bool {
        selected.contains(item.id)
    }
    
    var canSelectMore: Bool {
        guard let all = filterItems.first else { return false }
        return selected.subtracting([all.id]).count < maxRegularSelections
    }

    // MARK: - Private methods

    /// Wire the reactive graph:
    /// items + filterItems + selected  ==> visibleHabits  ==> months
    private func setupPipelines(anchor: Date = Date()) {
        // items + filterItems + selected + calendarAnchor  ==> months
        Publishers.CombineLatest4($items, $filterItems, $selected, $calendarAnchor)
            .map { items, filters, selected, anchor -> [HabitModel] in
                let picked = Set(selected)
                return items.filter { picked.contains($0.id) }
            }
            .removeDuplicates(by: { $0.map(\.id) == $1.map(\.id) })
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .filter { [weak self] _ in !(self?.isPriming ?? false) }
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
}
