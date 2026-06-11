//
//  HabitRepositoryProtocol.swift
//  HabitHonker
//

import Foundation

protocol HabitRepositoryProtocol {
    func fetchAll() async throws -> [HabitModel]
    func fetch(id: UUID) async throws -> HabitModel?
    func upsert(_ item: HabitModel) async throws
    func delete(id: UUID) async throws

    func fetchAllDeleted() async throws -> [HabitModel]
    func fetchDeleted(id: UUID) async throws -> HabitModel?
    func restoreDeletedHabit(id: UUID) async throws
    func permanentlyDeleteDeleted(id: UUID) async throws

    func fetchStatisticsPresetHabitIDs() async throws -> [UUID]?
    func saveStatisticsPresetHabitIDs(_ habitIDs: [UUID], presetName: String?) async throws
}
