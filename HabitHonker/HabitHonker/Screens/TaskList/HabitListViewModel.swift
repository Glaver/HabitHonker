//
//  HabitListViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/13/25.
//

import Foundation

@MainActor
final class HabitListViewModel: ObservableObject {
    @Published private(set) var items: [HabitModel] = []
    @Published private(set) var item: HabitModel = .init()
    @Published private(set) var newTag: String = ""
    @Published private(set) var deletedItems: [HabitModel] = []
    @Published private(set) var isLoading = false
    @Published var error: String?
    
    private let repo: HabitsRepositorySwiftData
    private let notifier: HabitNotificationScheduling
    private var didLoadOnce = false
    
    init(repo: HabitsRepositorySwiftData,
         notifier: HabitNotificationScheduling = HabitNotificationService()) {
        self.repo = repo
        self.notifier = notifier
    }
    
    // MARK: - Lifecycle
    func onAppear() async {
        await load()
    }
    
    func onAppLaunch() async {
        try? await notifier.requestAuthorization()
    }
    
    // MARK: Public methods
    func load(mode: HabitLoadMode = .all) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedItems = try await repo.fetchAll()
            let filteredItems: [HabitModel]
            
            switch mode {
            case .all:
                filteredItems = fetchedItems
                
            case .filteredByWeekday(let date):
                let targetWeekday = date.currentWeekday
                filteredItems = fetchedItems.filter { item in
                    if item.type == .repeating {
                        return item.repeating.contains(targetWeekday)
                    } else {
                        return true
                    }
                }
            }

            items = sortItems(filteredItems)
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func saveItem(_ item: HabitModel) async {
        setEditingItem(item)
        updateHabitNotification()
        await saveCurrent()
    }
    
    func deleteItem(_ item: HabitModel) async {
        deleteNotification(for: item.id)
        await deleteItem(withId: item.id)
    }
    
    func habitCompleteWith(id: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[index]
        item.completeHabitNow()
        setEditingItem(item)
        await saveCurrent()
    }
    
    func changePrirorityFor(_ id: UUID, to newPriority: HabitModel.PriorityEisenhower) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[index]
        item.priority = newPriority
        setEditingItem(item)
        await saveCurrent()
    }
    
    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await load()
    }
}
// MARK: Private methods

// MARK: Swift Data Methods
private extension HabitListViewModel {
    func delete(at offsets: IndexSet) async {
        do {
            for index in offsets {
                try await repo.delete(id: items[index].id)
            }
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func saveCurrent() async {
        do {
            for (index, record) in item.record.enumerated() {
            }
            
            if try await repo.fetch(id: item.id) != nil {
                try await repo.update(item)
            } else {
                try await repo.save(item)
            }
            
            // Small delay to ensure swipe action is completed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Reload items to apply sorting (completed tasks move to end)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteCurrent() async {
        do {
            try await repo.delete(id: item.id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteItem(withId id: UUID) async {
        do {
            try await repo.delete(id: id)
            // Small delay to ensure swipe action is completed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Deleted Habits Methods
    func loadDeletedHabits() async {
        do {
            deletedItems = try await repo.fetchAllDeleted()
            // You can add a separate @Published property for deleted habits if needed
            print("Found \(deletedItems.count) deleted habits")
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func restoreDeletedHabit(id: UUID) async {
        do {
            try await repo.restoreDeletedHabit(id: id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func permanentlyDeleteHabit(id: UUID) async {
        do {
            try await repo.permanentlyDeleteDeleted(id: id)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func setEditingItem(_ newItem: HabitModel) {
        self.item = newItem
    }
    
    //MARK: - Notifications
    
    func updateHabitNotification() {
        guard item.isNotificationActivated else { return }
        
        Task { try? await notifier.reschedule(for: item) }
    }
    
    func deleteNotification(for id: UUID) {
        guard item.isNotificationActivated else { return }
        
        Task { await notifier.cancel(for: id) }
    }
}

// MARK: - Helpers

extension HabitListViewModel {
    enum HabitLoadMode {
        case all
        case filteredByWeekday(Date)
    }
    
    func sortItems(_ items: [HabitModel]) -> [HabitModel] {
        return items.sorted { item1, item2 in
            if item1.isCompletedToday != item2.isCompletedToday {
                return !item1.isCompletedToday
            }
            if item1.priority.rawValue != item2.priority.rawValue {
                return item1.priority.rawValue < item2.priority.rawValue
            }
            return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
        }
    }
}

extension [HabitModel] {
    func filtered(by date: Date) -> [HabitModel] {
        let weekday = date.currentWeekday
        return self.filter {
            $0.type != .repeating || $0.repeating.contains(weekday)
        }
    }
}
