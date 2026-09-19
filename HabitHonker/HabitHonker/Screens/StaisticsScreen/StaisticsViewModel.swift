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
    private let statisticsService: StatisticsServiceProtocol
    private let habitEvents: HabitEventsPublishing?

    
    private var bag = Set<AnyCancellable>()

    // MARK: - Init
    init(statisticsService: StatisticsServiceProtocol,
         habitEvents: HabitEventsPublishing? = nil) {
        self.statisticsService = statisticsService
        self.habitEvents = habitEvents
        setupPipelines()
        subscribeToHabitEvents()
    }

    // MARK: - Public API
    
    func reloadStatistic(anchor: Date = Date()) {
        calendarAnchor = anchor   // triggers the pipeline above
    }
    
    func loadPresetHabits() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let resolved = try await statisticsService.fetchPresetHabits()
            
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

    func makeSelectHabitsViewModel() -> SelectHabitsViewModel {
        SelectHabitsViewModel(statisticsService: statisticsService,
                              selectionLimit: maxRegularSelections)
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
            .map { items, _, selected, _ -> [HabitModel] in
                let picked = Set(selected)
                return items.filter { picked.contains($0.id) }
            }
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

    private func subscribeToHabitEvents() {
        habitEvents?.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadPresetHabits() }
            }
            .store(in: &bag)
    }
}
