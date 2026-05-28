//
//  HabitServiceProtocol.swift
//  HabitHonker
//

import Foundation

protocol HabitServiceProtocol {
    func fetchHabits() async throws -> [HabitModel]
    func fetchHabit(id: UUID) async throws -> HabitModel?
    func saveHabit(_ habit: HabitModel) async throws
    func deleteHabit(id: UUID) async throws
    func completeHabit(id: UUID) async throws -> HabitModel?
    func changePriority(id: UUID, to priority: PriorityEisenhower) async throws -> HabitModel?
}
