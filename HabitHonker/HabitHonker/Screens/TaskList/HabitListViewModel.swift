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

    @Published var error: String?
    @Published private(set) var colors: [Color] = [.red, .yellow, .blue, .green]
    @Published private(set) var titles: [String] = ["", "", "", ""]
    @Published private(set) var backgroundImageData: Data? = nil

    private let log = Log.habitBeastVM
    private var inFlightOps = Set<UUID>()
    
    private let habitService: HabitServiceProtocol
    private let habitEvents: HabitEventsPublishing
    private let priorityThemeService: PriorityThemeServiceProtocol
    private let backgroundService: BackgroundServiceProtocol
    private let notifier: HabitNotificationScheduling
    private var cancellables = Set<AnyCancellable>()
    private var didLoadOnce = false
    private var isLoading = false
    private var isSaving = false
    private var resortWorkItem: DispatchWorkItem?

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
    
    init(habitService: HabitServiceProtocol,
         habitEvents: HabitEventsPublishing,
         priorityThemeService: PriorityThemeServiceProtocol,
         backgroundService: BackgroundServiceProtocol,
         notifier: HabitNotificationScheduling = HabitNotificationService()) {
        self.habitService = habitService
        self.habitEvents = habitEvents
        self.priorityThemeService = priorityThemeService
        self.backgroundService = backgroundService
        self.notifier = notifier
        subscribeToHabitEvents()
    }

    convenience init(usedDefaultsRepo: UserDefaultsStore,
                     repo: HabitsRepositorySwiftData,
                     notifier: HabitNotificationScheduling = HabitNotificationService()) {
        // TODO: Remove this fallback-only compatibility path after all call sites use AppDependencies.
        let habitEvents = HabitEventCenter()
        let habitRepository = SwiftDataHabitRepository(repository: repo)
        let habitService = HabitService(repository: habitRepository,
                                        habitEvents: habitEvents)
        self.init(habitService: habitService,
                  habitEvents: habitEvents,
                  priorityThemeService: PriorityThemeService(store: usedDefaultsRepo),
                  backgroundService: BackgroundService(),
                  notifier: notifier)
    }
    
    // MARK: - Lifecycle
    
    func onAppLaunch() async {
        try? await notifier.requestAuthorization()
    }

    func reloadAppearanceForDisplay() async {
        async let loadedColors = priorityThemeService.loadColors()
        async let loadedTitles = priorityThemeService.loadTitles()
        async let loadedBackground = backgroundService.loadBackgroundData()

        colors = padOrTrim(await loadedColors, to: 4, fill: .gray)
        titles = padOrTrim(await loadedTitles, to: 4, fill: "")
        backgroundImageData = await loadedBackground
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
            let fetchedItems = try await habitService.fetchHabits()
            
            log.debug("load fetched=\(fetchedItems.count)")
            let filteredItems = HabitSortFilterService.filtered(fetchedItems, mode: mode)

            if case .filteredByWeekday(let date) = mode {
                let targetWeekday = date.currentWeekday
                log.debug("weekday filter=\(targetWeekday.rawValue) -> \(filteredItems.count)")
            }
            
            items = HabitSortFilterService.sorted(filteredItems)
            
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
        await reconcileNotification(for: item)
        await saveCurrent()
    }
    
    func deleteItem(_ item: HabitModel) async {
        await deleteNotification(for: item)
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
        do {
            if let persisted = try await habitService.completeHabit(id: id) {
                upsertInMemory(persisted)
                setEditingItem(persisted)
            }
        } catch {
            self.error = error.localizedDescription
        }
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
    func subscribeToHabitEvents() {
        habitEvents.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.load() }
            }
            .store(in: &cancellables)
    }

    func delete(at offsets: IndexSet) async {
        do {
            let ids = offsets.map { items[$0].id }
            for id in ids {
                try await habitService.deleteHabit(id: id)
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
                self.items = HabitSortFilterService.sorted(self.items)
            }
            resortWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
    }
    
    func saveCurrent() async {
        do {
            try await habitService.saveHabit(item)
            upsertInMemory(item)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteCurrent() async {
        do {
            try await habitService.deleteHabit(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteItem(withId id: UUID) async {
        do {
            try await habitService.deleteHabit(id: id)
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
            deletedItems = try await habitService.fetchDeletedHabits()
            // You can add a separate @Published property for deleted habits if needed
            print("Found \(deletedItems.count) deleted habits")
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func restoreDeletedHabit(id: UUID) async {
        do {
            try await habitService.restoreDeletedHabit(id: id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func permanentlyDeleteHabit(id: UUID) async {
        do {
            try await habitService.permanentlyDeleteDeleted(id: id)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func setEditingItem(_ newItem: HabitModel) {
        self.item = newItem
    }
    
    //MARK: - Notifications
    
    func reconcileNotification(for item: HabitModel) async {
        if item.isNotificationActivated {
            try? await notifier.reschedule(for: item)
        } else {
            await notifier.cancel(for: item.id)
        }
    }
    
    func deleteNotification(for item: HabitModel) async {
        await notifier.cancel(for: item.id)
    }

    func padOrTrim<T>(_ array: [T], to length: Int, fill: @autoclosure () -> T) -> [T] {
        if array.count == length { return array }
        if array.count > length { return Array(array.prefix(length)) }
        var output = array
        output.append(contentsOf: Array(repeating: fill(), count: length - array.count))
        return output
    }
}
