//
//  HabitServiceProtocol.swift
//  HabitHonker
//

import Foundation

protocol HabitServiceProtocol {
    func fetchHabits() async throws -> [HabitModel]
    func fetchHabit(id: UUID) async throws -> HabitModel?
    /// Creates a habit from the add-new screen; `habit.record` is ignored (a new habit has no history).
    func createHabit(_ habit: HabitModel) async throws -> HabitModel
    /// Saves Details edits (metadata only); `habit.record` is ignored. Returns the fresh
    /// persisted habit. Throws `HabitRepositoryError.notFound` if the habit no longer exists.
    func updateHabit(_ habit: HabitModel) async throws -> HabitModel
    func deleteHabit(id: UUID) async throws
    func completeHabit(id: UUID) async throws -> HabitModel?
    func changePriority(id: UUID, to priority: PriorityEisenhower) async throws -> HabitModel?

    func fetchDeletedHabits() async throws -> [HabitModel]
    func fetchDeletedHabit(id: UUID) async throws -> HabitModel?
    func restoreDeletedHabit(id: UUID) async throws
    func permanentlyDeleteDeleted(id: UUID) async throws
}
