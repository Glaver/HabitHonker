//
//  SettingsViewModel.swift
//  HabitHonker
//

import PhotosUI
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var priorityColors: [Color] = [.red, .yellow, .blue, .green]
    @Published private(set) var priorityTitles: [String] = [
        PriorityEisenhower.importantAndUrgent.text,
        PriorityEisenhower.urgentButNotImportant.text,
        PriorityEisenhower.importantButNotUrgent.text,
        PriorityEisenhower.notUrgentAndNotImportant.text
    ]
    @Published private var themeDraft: ThemeDraft?
    @Published private(set) var backgroundData: Data?
    @Published var backgroundPickerItem: PhotosPickerItem?
    @Published var error: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false

    private let priorityThemeService: PriorityThemeServiceProtocol
    private let backgroundService: BackgroundServiceProtocol

    var hasCustomBackground: Bool {
        backgroundData != nil
    }

    init(
        priorityThemeService: PriorityThemeServiceProtocol,
        backgroundService: BackgroundServiceProtocol
    ) {
        self.priorityThemeService = priorityThemeService
        self.backgroundService = backgroundService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let colors = priorityThemeService.loadColors()
        async let titles = priorityThemeService.loadTitles()
        async let background = backgroundService.loadBackgroundData()

        priorityColors = padOrTrim(await colors, to: 4, fill: .gray)
        priorityTitles = padOrTrim(await titles, to: 4, fill: "")
        backgroundData = await background
    }

    func startThemeEditing() {
        themeDraft = ThemeDraft(colors: priorityColors, titles: priorityTitles)
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
                if value.isEmpty { value = priority.text }
                guard self.themeDraft?.titles.indices.contains(priority.index) == true else { return }
                self.themeDraft?.titles[priority.index] = value
            }
        )
    }

    func commitThemeChanges() async {
        guard var draft = themeDraft else { return }
        normalize(&draft)

        isSaving = true
        defer { isSaving = false }

        await priorityThemeService.setColors(draft.colors)
        await priorityThemeService.setTitles(draft.titles)
        priorityColors = draft.colors
        priorityTitles = draft.titles
        themeDraft = nil
    }

    func cancelThemeChanges() {
        themeDraft = nil
    }

    func resetPriorityTheme() async {
        await priorityThemeService.resetToDefaults()
        await load()
    }

    func processPickedBackgroundIfNeeded() async {
        guard let item = backgroundPickerItem else { return }

        isSaving = true
        defer {
            isSaving = false
            backgroundPickerItem = nil
        }

        do {
            if let raw = try await item.loadTransferable(type: Data.self) {
                let optimized = await backgroundService.optimizedBackgroundData(from: raw, maxDimension: 3000)
                await backgroundService.saveBackgroundData(optimized)
                backgroundData = optimized
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearBackground() async {
        await backgroundService.clearBackground()
        backgroundData = nil
    }

    private func normalize(_ draft: inout ThemeDraft) {
        draft.colors = padOrTrim(draft.colors, to: 4, fill: .gray)
        draft.titles = padOrTrim(draft.titles, to: 4, fill: "")
    }

    private func padOrTrim<T>(_ array: [T], to length: Int, fill: @autoclosure () -> T) -> [T] {
        if array.count == length { return array }
        if array.count > length { return Array(array.prefix(length)) }
        var output = array
        output.append(contentsOf: Array(repeating: fill(), count: length - array.count))
        return output
    }
}

private struct ThemeDraft {
    var colors: [Color]
    var titles: [String]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
