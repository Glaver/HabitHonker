//
//  HabitListViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/13/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class HabitListViewModel: ObservableObject {

    @Published private(set) var items: [HabitModel] = []
    @Published private(set) var item: HabitModel = .mock()
    @Published private(set) var newTag: String = ""
    @Published private(set) var deletedItems: [HabitModel] = []
    private var isLoading = false
    private var isSaving = false
    @Published var error: String?
    @Published private(set) var colors: [Color] = [.red, .yellow, .blue, .green]
    @Published private(set) var titles: [String] = ["", "", "", ""]
    private let log = Log.habitBeastVM
    private var inFlightOps = Set<UUID>()
    private let usedDefaultsRepo: RepositoryUserDefaults
    private let repo: HabitsRepositorySwiftData
    private let notifier: HabitNotificationScheduling
    private var didLoadOnce = false
    
    init(usedDefaultsRepo: RepositoryUserDefaults = .shared,
         repo: HabitsRepositorySwiftData,
         notifier: HabitNotificationScheduling = HabitNotificationService()) {
        self.usedDefaultsRepo = usedDefaultsRepo
        self.repo = repo
        self.notifier = notifier
    }
    
    // MARK: - Lifecycle

    func onAppLaunch() async {
        try? await notifier.requestAuthorization()
    }
    
    // MARK: Public methods
    func load(mode: HabitLoadMode = .all) async {
        guard !isLoading else {
                    log.debug("load(\(String(describing: mode))) skipped — already loading")
                    return
                }
        isLoading = true
        let t0 = DispatchTime.now()
        log.info("⬇️ load start mode=\(String(describing: mode))")
        
        defer { isLoading = false
            let ns = DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds
            log.info("✅ load end items=\(self.items.count) in \(Double(ns)/1_000_000.0, privacy: .public) ms")}
        
        do {
            let fetchedItems = try await repo.fetchAll()
            log.debug("load fetched=\(fetchedItems.count)")
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
                log.debug("weekday filter=\(targetWeekday.rawValue) -> \(filteredItems.count)")
            }

            items = sortItems(filteredItems)
            
        } catch {
            self.error = error.localizedDescription
            log.error("❌ load failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func saveItem(_ item: HabitModel) async {
        guard !isSaving else {
                    log.debug("saveItem skipped — saving in progress")
                    return
                }
        isSaving = true
        let opID = UUID() // correlation id for this save action
        log.info("💾 saveItem start id=\(item.id.uuidString, privacy: .public) title=\(item.title, privacy: .public) op=\(opID.uuidString, privacy: .public)")
        defer { isSaving = false
                log.info("✅ saveItem end op=\(opID.uuidString, privacy: .public)")}
        setEditingItem(item)
        updateHabitNotification()
        await saveCurrent()
    }
    
    func deleteItem(_ item: HabitModel) async {
        deleteNotification(for: item.id)
        await deleteItem(withId: item.id)
    }
    
    func habitCompleteWith(id: UUID) async {
            guard !inFlightOps.contains(id),
                  let index = items.firstIndex(where: { $0.id == id }) else { return }
            inFlightOps.insert(id)
            defer { inFlightOps.remove(id) }

            var updated = items[index]
            updated.completeHabitNow()

            // Optimistic in-memory update FIRST (cheap, avoids extra fetch loops)
            upsertInMemory(updated)

            // Persist (no extra fetch before update, see #2)
            setEditingItem(updated)
            await saveCurrent()
//        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        //        var item = items[index]
        //        item.completeHabitNow()
        //        setEditingItem(item)
        //        await saveCurrent()
        }
        
//
    
    
    func changePrirorityFor(_ id: UUID, to newPriority: PriorityEisenhower) async {
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
            let ids = offsets.map { items[$0].id }
            for id in ids {
                try await repo.delete(id: id)
            }
            items.removeAll { ids.contains($0.id) }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func upsertInMemory(_ updated: HabitModel) {
        if let idx = items.firstIndex(where: { $0.id == updated.id }) {
            items[idx] = updated
        } else {
            items.append(updated)
        }
        // Defer the expensive re-sort until after the swipe collapses
        DispatchQueue.main.async { [items] in
            self.items = self.sortItems(items)
        }
    }

    func saveCurrent() async {
        do {
            try await repo.upsert(item)   
            upsertInMemory(item)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteCurrent() async {
        do {
            try await repo.delete(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteItem(withId id: UUID) async {
        do {
            try await repo.delete(id: id)
            // Small delay to ensure swipe action is completed
            items.removeAll { $0.id == id }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
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

// MARK: - UsedDefaultsRepo

extension HabitListViewModel {
    // MARK: - Load / Reset
       func reloadTheme() async {
           colors = await usedDefaultsRepo.loadColors()
           titles = await usedDefaultsRepo.loadTitles()
       }

       func resetToDefaults() {
           Task {
               await usedDefaultsRepo.resetToDefaults()
               await reloadTheme()
           }
       }

       // MARK: - Mutators (no computed props)
       func setColor(_ color: Color, at index: Int) {
           guard colors.indices.contains(index) else { return }
           colors[index] = color                      // update stored state
           Task { await usedDefaultsRepo.setColor(color, at: index) } // persist
       }

       func setTitle(_ title: String, for prio: PriorityEisenhower) {
           titles[prio.index] = title
           Task { await usedDefaultsRepo.setTitle(title, for: prio) }
       }

       // MARK: - Optional Bindings for SwiftUI controls
       func colorBinding(_ index: Int) -> Binding<Color> {
           Binding(
               get: { self.colors[index] },
               set: { self.setColor($0, at: index) }
           )
       }

       func titleBinding(_ prio: PriorityEisenhower) -> Binding<String> {
           Binding(
               get: { self.titles[prio.index] },
               set: { self.setTitle($0, for: prio) }
           )
       
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
