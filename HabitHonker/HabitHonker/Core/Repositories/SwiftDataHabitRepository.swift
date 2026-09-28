//
//  SwiftDataHabitRepository.swift
//  HabitHonker
//

import Foundation
import SwiftData

struct SwiftDataHabitRepository: HabitRepositoryProtocol {
    private let repository: HabitsRepositorySwiftData

    init(repository: HabitsRepositorySwiftData) {
        self.repository = repository
    }

    init(container: ModelContainer) {
        self.repository = HabitsRepositorySwiftData(container: container)
    }

    func fetchAll() async throws -> [HabitModel] {
        try await repository.fetchAll()
    }

    func fetch(id: UUID) async throws -> HabitModel? {
        try await repository.fetch(id: id)
    }

    func createHabit(id: UUID, metadata: HabitMetadata) async throws -> HabitModel {
        try await repository.createHabit(id: id, metadata: metadata)
    }

    func updateMetadata(id: UUID, metadata: HabitMetadata) async throws -> HabitModel {
        try await repository.updateMetadata(id: id, metadata: metadata)
    }

    func updatePriority(id: UUID, priority: PriorityEisenhower) async throws -> HabitModel {
        try await repository.updatePriority(id: id, priority: priority)
    }

    func recordLegacyCompletion(id: UUID, at date: Date, calendar: Calendar) async throws -> HabitModel {
        try await repository.recordLegacyCompletion(id: id, at: date, calendar: calendar)
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func fetchAllDeleted() async throws -> [HabitModel] {
        try await repository.fetchAllDeleted()
    }

    func fetchDeleted(id: UUID) async throws -> HabitModel? {
        try await repository.fetchDeleted(id: id)
    }

    func restoreDeletedHabit(id: UUID) async throws {
        try await repository.restoreDeletedHabit(id: id)
    }

    func permanentlyDeleteDeleted(id: UUID) async throws {
        try await repository.permanentlyDeleteDeleted(id: id)
    }

    func fetchStatisticsPresetHabitIDs() async throws -> [UUID]? {
        try await repository.fetchStatisticsPresetHabitIDs()
    }

    func saveStatisticsPresetHabitIDs(_ habitIDs: [UUID], presetName: String?) async throws {
        try await repository.saveStatisticsPreset(habitIDs, presetName: presetName)
    }
}
