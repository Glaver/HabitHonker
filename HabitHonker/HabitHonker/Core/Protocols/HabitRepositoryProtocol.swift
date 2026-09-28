//
//  HabitRepositoryProtocol.swift
//  HabitHonker
//

import Foundation

protocol HabitRepositoryProtocol {
    func fetchAll() async throws -> [HabitModel]
    func fetch(id: UUID) async throws -> HabitModel?

    /// Inserts a new habit with no completion history. Throws `HabitRepositoryError.alreadyExists`.
    func createHabit(id: UUID, metadata: HabitMetadata) async throws -> HabitModel
    /// Writes editable fields only and returns the fresh persisted habit (with its current
    /// records). Throws `HabitRepositoryError.notFound`; never inserts.
    func updateMetadata(id: UUID, metadata: HabitMetadata) async throws -> HabitModel
    /// Writes the priority only. Throws `HabitRepositoryError.notFound`; never inserts.
    func updatePriority(id: UUID, priority: PriorityEisenhower) async throws -> HabitModel
    /// Legacy same-day completion for the `calendar` day containing `date`, in one repository
    /// operation. Throws `HabitRepositoryError.notFound`; never inserts a habit.
    func recordLegacyCompletion(id: UUID, at date: Date, calendar: Calendar) async throws -> HabitModel

    func delete(id: UUID) async throws

    func fetchAllDeleted() async throws -> [HabitModel]
    func fetchDeleted(id: UUID) async throws -> HabitModel?
    func restoreDeletedHabit(id: UUID) async throws
    func permanentlyDeleteDeleted(id: UUID) async throws

    func fetchStatisticsPresetHabitIDs() async throws -> [UUID]?
    func saveStatisticsPresetHabitIDs(_ habitIDs: [UUID], presetName: String?) async throws
}
