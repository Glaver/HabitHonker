//
//  PriorityMatrixViewModel.swift
//  HabitHonker
//

import Foundation
import SwiftUI

@MainActor
final class PriorityMatrixViewModel: ObservableObject {
    @Published private(set) var items: [HabitModel] = []
    @Published private(set) var colors: [Color] = [.red, .yellow, .blue, .green]
    @Published private(set) var titles: [String] = [
        PriorityEisenhower.importantAndUrgent.text,
        PriorityEisenhower.urgentButNotImportant.text,
        PriorityEisenhower.importantButNotUrgent.text,
        PriorityEisenhower.notUrgentAndNotImportant.text
    ]
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let habitService: HabitServiceProtocol
    private let themeService: PriorityThemeServiceProtocol?

    init(
        habitService: HabitServiceProtocol,
        themeService: PriorityThemeServiceProtocol? = nil
    ) {
        self.habitService = habitService
        self.themeService = themeService
    }

    func refresh() async {
        await reloadTheme()
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedItems = try await habitService.fetchHabits()
            items = HabitSortFilterService.sorted(fetchedItems)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reloadTheme() async {
        guard let themeService else { return }
        colors = padOrTrim(await themeService.loadColors(), to: 4, fill: .gray)
        titles = padOrTrim(await themeService.loadTitles(), to: 4, fill: "")
    }

    func habits(for priority: PriorityEisenhower) -> [HabitModel] {
        items.filter { $0.priority == priority }
    }

    func color(for priority: PriorityEisenhower) -> Color {
        colors[safe: priority.index] ?? priority.color
    }

    func title(for priority: PriorityEisenhower) -> String {
        titles[safe: priority.index] ?? priority.text
    }

    func changePriorityFor(_ id: UUID, to newPriority: PriorityEisenhower) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        var item = items[index]
        item.priority = newPriority
        upsertInMemory(item)

        do {
            if let persisted = try await habitService.changePriority(id: id, to: newPriority) {
                upsertInMemory(persisted)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func changePriorityFor(_ ids: [UUID], to newPriority: PriorityEisenhower) async {
        for id in ids {
            await changePriorityFor(id, to: newPriority)
        }
    }

    private func upsertInMemory(_ updated: HabitModel) {
        if let index = items.firstIndex(where: { $0.id == updated.id }) {
            items[index] = updated
        } else {
            items.append(updated)
        }
        items = HabitSortFilterService.sorted(items)
    }

    private func padOrTrim<T>(_ array: [T], to length: Int, fill: @autoclosure () -> T) -> [T] {
        if array.count == length { return array }
        if array.count > length { return Array(array.prefix(length)) }
        var output = array
        output.append(contentsOf: Array(repeating: fill(), count: length - array.count))
        return output
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
