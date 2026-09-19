//
//  HabitService.swift
//  HabitHonker
//

import Foundation

final class HabitService: HabitServiceProtocol {
    private let repository: HabitRepositoryProtocol
    private let habitEvents: HabitEventsPublishing

    init(repository: HabitRepositoryProtocol,
         habitEvents: HabitEventsPublishing) {
        self.repository = repository
        self.habitEvents = habitEvents
    }

    func fetchHabits() async throws -> [HabitModel] {
        try await repository.fetchAll()
    }

    func fetchHabit(id: UUID) async throws -> HabitModel? {
        try await repository.fetch(id: id)
    }

    func saveHabit(_ habit: HabitModel) async throws {
        let existing = try await repository.fetch(id: habit.id)
        try await repository.upsert(habit)
        habitEvents.send(existing == nil ? .created : .updated)
    }

    func deleteHabit(id: UUID) async throws {
        try await repository.delete(id: id)
        habitEvents.send(.deleted)
    }

    func completeHabit(id: UUID) async throws -> HabitModel? {
        guard var habit = try await repository.fetch(id: id) else { return nil }
        habit.completeHabitNow()
        try await repository.upsert(habit)
        habitEvents.send(.completed)
        return habit
    }

    func changePriority(id: UUID, to priority: PriorityEisenhower) async throws -> HabitModel? {
        guard var habit = try await repository.fetch(id: id) else { return nil }
        habit.priority = priority
        try await repository.upsert(habit)
        habitEvents.send(.priorityChanged)
        return habit
    }

    func fetchDeletedHabits() async throws -> [HabitModel] {
        try await repository.fetchAllDeleted()
    }

    func fetchDeletedHabit(id: UUID) async throws -> HabitModel? {
        try await repository.fetchDeleted(id: id)
    }

    func restoreDeletedHabit(id: UUID) async throws {
        try await repository.restoreDeletedHabit(id: id)
        habitEvents.send(.restored)
    }

    func permanentlyDeleteDeleted(id: UUID) async throws {
        try await repository.permanentlyDeleteDeleted(id: id)
        habitEvents.send(.deleted)
    }
}
