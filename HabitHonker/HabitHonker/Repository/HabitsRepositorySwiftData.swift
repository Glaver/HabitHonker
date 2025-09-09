//
//  HabitsRepositorySwiftData.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/12/25.
//
import Foundation
import SwiftData

actor HabitsRepositorySwiftData {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Helpers
    private func makeContext() -> ModelContext {
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return ctx
    }

    // MARK: - CRUD
    func fetchAll() throws -> [HabitModel] {
        let ctx = makeContext()
        let descriptor = FetchDescriptor<HabitSD>(sortBy: [.init(\.title)])
        let rows = try ctx.fetch(descriptor)
        return rows.map(HabitMapper.toDomain)
    }

    func fetch(id: UUID) throws -> HabitModel? {
        let ctx = makeContext()
        let pred = #Predicate<HabitSD> { $0.id == id }
        var d = FetchDescriptor<HabitSD>(predicate: pred)
        d.fetchLimit = 1
        return try ctx.fetch(d).first.map(HabitMapper.toDomain)
    }

    func save(_ item: HabitModel) throws {
        let ctx = makeContext()
        let sd = HabitMapper.makeSD(from: item)
        ctx.insert(sd)
        try ctx.save()
    }

    func update(_ item: HabitModel) throws {
        let ctx = makeContext()

        // 👈 capture the value FIRST so RHS is a literal, not a key path
        let targetId = item.id

        let pred = #Predicate<HabitSD> { $0.id == targetId }

        var descriptor = FetchDescriptor<HabitSD>(predicate: pred)
        descriptor.fetchLimit = 1

        if let sd = try ctx.fetch(descriptor).first {
            HabitMapper.apply(item, to: sd)
            try ctx.save()
        }
    }

    func delete(id: UUID) throws {
        let ctx = makeContext()
        let pred = #Predicate<HabitSD> { $0.id == id }
        var d = FetchDescriptor<HabitSD>(predicate: pred)
        d.fetchLimit = 1
        if let sd = try ctx.fetch(d).first {
            // Archive the habit before deleting
            let deletedHabit = HabitMapper.makeDeletedSD(from: HabitMapper.toDomain(sd))
            ctx.insert(deletedHabit)
            
            // Delete the original habit
            ctx.delete(sd)
            try ctx.save()
        }
    }
    
    // MARK: - Deleted Habits Methods
    func fetchAllDeleted() throws -> [HabitModel] {
        let ctx = makeContext()
        let descriptor = FetchDescriptor<DeletedHabitSD>(sortBy: [.init(\.deletedAt, order: .reverse)])
        let rows = try ctx.fetch(descriptor)
        return rows.map(HabitMapper.deletedToDomain)
    }
    
    func fetchDeleted(id: UUID) throws -> HabitModel? {
        let ctx = makeContext()
        let pred = #Predicate<DeletedHabitSD> { $0.id == id }
        var d = FetchDescriptor<DeletedHabitSD>(predicate: pred)
        d.fetchLimit = 1
        return try ctx.fetch(d).first.map(HabitMapper.deletedToDomain)
    }
    
    func permanentlyDeleteDeleted(id: UUID) throws {
        let ctx = makeContext()
        let pred = #Predicate<DeletedHabitSD> { $0.id == id }
        var d = FetchDescriptor<DeletedHabitSD>(predicate: pred)
        d.fetchLimit = 1
        if let sd = try ctx.fetch(d).first {
            ctx.delete(sd)
            try ctx.save()
        }
    }
    
    func restoreDeletedHabit(id: UUID) throws {
        let ctx = makeContext()
        let pred = #Predicate<DeletedHabitSD> { $0.id == id }
        var d = FetchDescriptor<DeletedHabitSD>(predicate: pred)
        d.fetchLimit = 1
        if let deletedSD = try ctx.fetch(d).first {
            // Convert back to regular habit
            let restoredHabit = HabitMapper.deletedToDomain(deletedSD)
            let habitSD = HabitMapper.makeSD(from: restoredHabit)
            ctx.insert(habitSD)
            
            // Remove from deleted habits
            ctx.delete(deletedSD)
            try ctx.save()
        }
    }

    
    // MARK: - Statistics Preset
    
    // MARK: - Statistics Preset

    func fetchStatisticsPreset() async throws -> StatisticsPresetSD? {
        let ctx = makeContext()
        let descriptor = FetchDescriptor<StatisticsPresetSD>(
            sortBy: [SortDescriptor(\.id)]
        )
        return try ctx.fetch(descriptor).first
    }

    func saveStatisticsPreset(_ habitIDs: [UUID], presetName: String? = nil) async throws {
        let ctx = makeContext()

        // IMPORTANT: fetch with the SAME ctx you will save
        let descriptor = FetchDescriptor<StatisticsPresetSD>(
            sortBy: [SortDescriptor(\.id)]
        )
        if let existing = try ctx.fetch(descriptor).first {
            existing.habitIDs = habitIDs
            existing.presetName = presetName
        } else {
            let newPreset = StatisticsPresetSD(habitIDs: habitIDs, presetName: presetName)
            ctx.insert(newPreset)
        }

        try ctx.save()
    }

    func deleteStatisticsPreset() async throws {
        let ctx = makeContext()
        let descriptor = FetchDescriptor<StatisticsPresetSD>(
            sortBy: [SortDescriptor(\.id)]
        )
        if let existing = try ctx.fetch(descriptor).first {
            ctx.delete(existing)
            try ctx.save()
        }
    }
}



