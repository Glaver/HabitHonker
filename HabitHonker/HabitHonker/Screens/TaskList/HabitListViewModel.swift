//
//  HabitListViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/13/25.
//
import Foundation

@MainActor
final class HabitListViewModel: ObservableObject {
    @Published private(set) var items: [ListHabitItem] = []
    @Published private(set) var item: ListHabitItem = .init()
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let repo: HabitsRepositorySwiftData
    init(repo: HabitsRepositorySwiftData) {
        self.repo = repo
    }

    // MARK: - Lifecycle
    func onAppear() { Task { await load() } }

    // MARK: - Actions
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetchedItems = try await repo.fetchAll()
            // Sort items: active tasks first, completed tasks at the end
            items = fetchedItems.sorted { item1, item2 in
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

    // Удобный helper, если хочешь отдать новый item из формы
    func setEditingItem(_ newItem: ListHabitItem) {
        self.item = newItem
    }
}
//
//final class HabitListViewModel: ObservableObject {
//    @Published private(set) var items: [ListHabitItem] = []
//    @Published private(set) var item: ListHabitItem = .init()
//    @Published private(set) var isLoading = false
//    @Published var error: String?
//
//    private let repo: HabitsRepositorySwiftData
//    init(repo: HabitsRepositorySwiftData) { self.repo = repo }
//
//    func onAppear() { Task { await load() } }
//
//    func load() async {
//        isLoading = true
//        defer { isLoading = false }
//        do { items = try await repo.fetchAll() }
//        catch { self.error = error.localizedDescription }
//    }
//
//    func delete(at offsets: IndexSet) {
//        Task {
//            for index in offsets {
//                try? await repo.delete(id: items[index].id)
//            }
//            await load()
//        }
//    }
//    
//    func save() async {
//        Task {
//            do {
//                // upsert depending on existence
//                if try await repo.fetch(id: item.id) != nil {
//                    try await repo.update(item)
//                } else {
//                    try await repo.save(item)
//                }
//            } catch {
//                self.error = error.localizedDescription
//            }
//        }
//    }
//    
//    func delete() async {
//        try? await repo.delete(id: item.id)
//    }
//}
