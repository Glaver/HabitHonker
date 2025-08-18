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
    @Published private(set) var isLoading = false
    @Published var error: String?
    
    private let repo: HabitsRepositorySwiftData
    private let notifier: HabitNotificationScheduling
    
    init(repo: HabitsRepositorySwiftData,
         notifier: HabitNotificationScheduling = HabitNotificationService()) {
        self.repo = repo
        self.notifier = notifier
        Task { try? await notifier.requestAuthorization() }
    }
    
    // MARK: - Lifecycle
    func onAppear() {
        Task { await load() }
    }
    
    func onAppLaunch() {
        Task { try? await notifier.requestAuthorization() }
    }
    
    // MARK: - Actions
    func load(forDate date: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetchedItems = try await repo.fetchAll()
            
            // Filter items based on specified day of week for repeating tasks
            let targetWeekday = date.currentWeekday
            
            let filteredItems = fetchedItems.filter { item in
                if item.type == .repeating {
                    // For repeating tasks, only show if the target day is in the repeating weekdays
                    return item.repeating.contains(targetWeekday)
                } else {
                    // For due date tasks, show them always
                    return true
                }
            }
            
            // Sort items: active tasks first, completed tasks at the end
            items = filteredItems.sorted { item1, item2 in
                let item1Completed = item1.isCompletedToday
                let item2Completed = item2.isCompletedToday
                
                // If one is completed and the other isn't, put the active one first
                if item1Completed != item2Completed {
                    return !item1Completed // true (active) comes before false (completed)
                }
                
                // If both have the same completion status, sort by priority and then by title
                if item1Completed == item2Completed {
                    // Sort by priority first (lower raw value = higher priority)
                    if item1.priority.rawValue != item2.priority.rawValue {
                        return item1.priority.rawValue < item2.priority.rawValue
                    }
                    // Then by title
                    return item1.title.localizedCaseInsensitiveCompare(item2.title) == .orderedAscending
                }
                
                return false
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    // MARK: Public methods
    func saveItem(_ item: HabitModel) {
        Task {
            setEditingItem(item) // NEED REFACTOR
            await saveCurrent()
            updateHabitNotification()
        }
    }
    
    func deleteItem(_ item: HabitModel) {
        Task {
            setEditingItem(item) // NEED REFACTOR
            await deleteItem(withId: item.id) // NEED REFACTOR
            deleteNotification(for: item.id) // NEED REFACTOR
        }
    }
    
    func habitComplete() {
//        Task {
            // Need to improve logic for finish Habit
            
//            item.completeHabitNow() // NEED REFACTOR
//            await saveCurrent()
//            setEditingItem(item) // NEED REFACTOR
//        }
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
            print("Saving item with ID: \(item.id)")
            print("Item has \(item.record.count) records")
            for (index, record) in item.record.enumerated() {
                print("Record \(index): id=\(record.id), date=\(record.date), count=\(record.count)")
            }
            
            // upsert
            if try await repo.fetch(id: item.id) != nil {
                print("Updating existing item")
                try await repo.update(item)
            } else {
                print("Creating new item")
                try await repo.save(item)
            }
            
            // Small delay to ensure swipe action is completed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Reload items to apply sorting (completed tasks move to end)
            await load()
            print("items = try await repo.fetchAll()")
        } catch {
            print("Error saving item: \(error)")
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
            let deletedItems = try await repo.fetchAllDeleted()
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

