//
//  HabitListViewModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/13/25.
//

import Foundation
import Combine
import SwiftUI
import PhotosUI

@MainActor
final class HabitListViewModel: ObservableObject {
    @Published private(set) var items: [HabitModel] = []
    @Published private(set) var item: HabitModel = .mock()
    @Published private(set) var newTag: String = ""
    @Published private(set) var deletedItems: [HabitModel] = []

    @Published var error: String?
    @Published private(set) var colors: [Color] = [.red, .yellow, .blue, .green]
    @Published private(set) var titles: [String] = ["", "", "", ""]
    @Published var themeDraft: ThemeDraft? = nil
    @Published var backgroundImageData: Data? = nil
    @Published var backgroundPickerItem: PhotosPickerItem? = nil

    private let log = Log.habitBeastVM
    private var inFlightOps = Set<UUID>()
    
    private let usedDefaultsRepo: UserDefaultsStore
    private let repo: HabitsRepositorySwiftData
    private let notifier: HabitNotificationScheduling
    private var didLoadOnce = false
    private var isLoading = false
    private var isSaving = false
    private var resortWorkItem: DispatchWorkItem?
    var hasCustomBackground: Bool { backgroundImageData != nil }

    var backgroundUIImage: UIImage? {
        guard let data = backgroundImageData else { return nil }
        // Pre-decode: draw into CGImage once so UIKit doesn’t do it lazily on the first render
        guard let img = UIImage(data: data) else { return nil }
        UIGraphicsBeginImageContextWithOptions(img.size, true, img.scale)
        img.draw(at: .zero)
        let decoded = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return decoded
    }
    
    init(usedDefaultsRepo: UserDefaultsStore,
         repo: HabitsRepositorySwiftData,
         notifier: HabitNotificationScheduling = HabitNotificationService()) {
        self.usedDefaultsRepo = usedDefaultsRepo
        self.repo = repo
        self.notifier = notifier
    }
    
    // MARK: - Lifecycle
    
    func primeBackgroundFromDisk() {
        Task.detached(priority: .utility) { [weak self] in
            let data = BackgroundStorage.load()
            await MainActor.run { self?.backgroundImageData = data }
        }
    }
    
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
            let fetchedItems: [HabitModel] = try await Task.detached(priority: .userInitiated) { [repo] in
                        try await repo.fetchAll()
            }.value
            
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
        
        upsertInMemory(updated)

        setEditingItem(updated)
        await saveCurrent()
    }
    
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

// MARK: - Color theme

extension HabitListViewModel {
    func startThemeEditing() {
        themeDraft = ThemeDraft(colors: colors, titles: titles)
    }
    
    func draftColorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: { self.themeDraft?.colors[safe: index] ?? .clear },
            set: { newValue in
                guard self.themeDraft?.colors.indices.contains(index) == true else { return }
                self.themeDraft?.colors[index] = newValue
            }
        )
    }

    func draftTitleBinding(_ priority: PriorityEisenhower) -> Binding<String> {
        Binding(
            get: { self.themeDraft?.titles[safe: priority.index] ?? priority.text },
            set: { newValue in
                var value = newValue
                if value.isEmpty { value = priority.text } // Safe deafult name priority name when empty
                guard self.themeDraft?.titles.indices.contains(priority.index) == true else { return }
                self.themeDraft?.titles[priority.index] = value
            }
        )
    }

    // 3) Commit (persist once, then publish live)
    func commitThemeChanges() {
        guard var draft = themeDraft else { return }
        normalize(&draft)

        // Persist once
        Task {
            await usedDefaultsRepo.setColors(draft.colors)
            await usedDefaultsRepo.setTitles(draft.titles)
            // Reflect in live state for the rest of the app
            await MainActor.run {
                self.colors = draft.colors
                self.titles = draft.titles
                self.themeDraft = nil
            }
        }
    }

    // 4) Cancel
    func cancelThemeChanges() {
        themeDraft = nil
    }

    // Ensure arrays are exactly 4 elements, clamp/extend to defaults if needed
    private func normalize(_ draft: inout ThemeDraft) {
        draft.colors = padOrTrim(draft.colors, to: 4, fill: .gray)
        draft.titles = padOrTrim(draft.titles, to: 4, fill: "")
    }

    private func padOrTrim<T>(_ array: [T], to len: Int, fill: @autoclosure () -> T) -> [T] {
        if array.count == len { return array }
        if array.count > len { return Array(array.prefix(len)) }
        var out = array
        out.append(contentsOf: Array(repeating: fill(), count: len - array.count))
        return out
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
        // Coalesce multiple updates within 60ms
            resortWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.items = self.sortItems(self.items)
            }
            resortWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
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

// MARK: 

extension HabitListViewModel {
    /// Call this when `backgroundPickerItem` changes.
    func processPickedBackgroundIfNeeded() async {
        guard let item = backgroundPickerItem else { return }
        do {
            if let raw = try await item.loadTransferable(type: Data.self) {
                let optimized = ImageOptimizer.downscaleIfNeeded(data: raw, maxDimension: 3000)
                backgroundImageData = optimized
                BackgroundStorage.save(optimized)          // persist via your existing repo
            }
        } catch {
            self.error = error.localizedDescription
        }
        // Reset selection so the same photo can be picked again if needed
        backgroundPickerItem = nil
    }

    func clearBackground() {
        backgroundImageData = nil
        BackgroundStorage.clear()
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
        let calendar = Calendar.current
        return self.filter { habit in
            switch habit.type {
            case .repeating:
                return habit.repeating.contains(weekday)
            case .dueDate:
                return calendar.isDate(habit.dueDate, inSameDayAs: date)
            }
        }
    }
    
    func filteredCompleted(on date: Date) -> [HabitModel] {
        self.filter { $0.isCompleted(on: date) }
    }
    
    func filteredNotForToday(by date: Date) -> [HabitModel] {
        let weekday = date.currentWeekday
        let calendar = Calendar.current
        
        return self.filter { habit in
            switch habit.type {
            case .repeating:
                return !habit.repeating.contains(weekday)
            case .dueDate:
                return !calendar.isDate(habit.dueDate, inSameDayAs: date)
            }
        }
    }
}

// MARK: - Theme Draft
struct ThemeDraft {
    var colors: [Color]
    var titles: [String]
}


private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
