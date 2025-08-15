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
            items = try await repo.fetchAll()   // await, т.к. вызов к actor
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(at offsets: IndexSet) async {
        do {
            for index in offsets {
                try await repo.delete(id: items[index].id)
            }
            items = try await repo.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveCurrent() async {
        do {
            // upsert
            if try await repo.fetch(id: item.id) != nil {
                try await repo.update(item)
            } else {
                try await repo.save(item)
            }
            items = try await repo.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCurrent() async {
        do {
            try await repo.delete(id: item.id)
            items = try await repo.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteItem(withId id: UUID) async {
        do {
            try await repo.delete(id: id)
            items = try await repo.fetchAll()
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
