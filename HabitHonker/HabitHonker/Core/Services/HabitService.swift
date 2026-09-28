//
//  HabitService.swift
//  HabitHonker
//

import Foundation

final class HabitService: HabitServiceProtocol {
    private let repository: HabitRepositoryProtocol
    private let habitEvents: HabitEventsPublishing
    private let now: () -> Date
    private let calendar: () -> Calendar

    /// `now` and `calendar` decide the legacy completion day. The defaults keep today's live
    /// behavior (wall clock + device calendar) at this application boundary; tests inject them.
    init(repository: HabitRepositoryProtocol,
         habitEvents: HabitEventsPublishing,
         now: @escaping () -> Date = { Date() },
         calendar: @escaping () -> Calendar = { Calendar.current }) {
        self.repository = repository
        self.habitEvents = habitEvents
        self.now = now
        self.calendar = calendar
    }

    func fetchHabits() async throws -> [HabitModel] {
        try await repository.fetchAll()
    }

    func fetchHabit(id: UUID) async throws -> HabitModel? {
        try await repository.fetch(id: id)
    }

    func createHabit(_ habit: HabitModel) async throws -> HabitModel {
        let created = try await repository.createHabit(id: habit.id, metadata: HabitMetadata(habit))
        habitEvents.send(.created)
        return created
    }

    func updateHabit(_ habit: HabitModel) async throws -> HabitModel {
        let updated = try await repository.updateMetadata(id: habit.id, metadata: HabitMetadata(habit))
        habitEvents.send(.updated)
        return updated
    }

    func deleteHabit(id: UUID) async throws {
        try await repository.delete(id: id)
        habitEvents.send(.deleted)
    }

    /// Legacy completion (no gamification). Returns nil when the habit no longer exists.
    func completeHabit(id: UUID) async throws -> HabitModel? {
        do {
            let habit = try await repository.recordLegacyCompletion(id: id, at: now(), calendar: calendar())
            habitEvents.send(.completed)
            return habit
        } catch let error as HabitRepositoryError {
            if case .notFound = error { return nil }
            throw error
        }
    }

    /// Changes only the priority. Returns nil when the habit no longer exists.
    func changePriority(id: UUID, to priority: PriorityEisenhower) async throws -> HabitModel? {
        do {
            let habit = try await repository.updatePriority(id: id, priority: priority)
            habitEvents.send(.priorityChanged)
            return habit
        } catch let error as HabitRepositoryError {
            if case .notFound = error { return nil }
            throw error
        }
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
