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

    func upsert(_ item: HabitModel) async throws {
        try await repository.upsert(item)
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
