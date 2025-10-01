//
//  HabitsRepositorySwiftData.swift
//  HabitHonker
//

import Foundation
import SwiftData
import os

actor HabitsRepositorySwiftData {
    private let container: ModelContainer
    private let log = Log.repoSD

    init(container: ModelContainer) {
        self.container = container
        log.info("📦 Repo init with container: \(String(describing: container), privacy: .public)")
    }

    // MARK: - Helpers
    private func makeContext() -> ModelContext {
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return ctx
    }

    // MARK: - CRUD
    func fetchAll() throws -> [HabitModel] {
        let t0 = DispatchTime.now()
        log.info("⬇️ fetchAll start")
        do {
            let ctx = makeContext()
            let descriptor = FetchDescriptor<HabitSD>(sortBy: [.init(\.title)])
            let rows = try ctx.fetch(descriptor)
            let models = rows.map(HabitMapper.toDomain)
            log.info("✅ fetchAll end sd=\(rows.count) models=\(models.count) in \(elapsedMS(from: t0), privacy: .public) ms")
            return models
        } catch {
            log.error("❌ fetchAll failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func fetch(id: UUID) throws -> HabitModel? {
        let t0 = DispatchTime.now()
        log.info("⬇️ fetch id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let pred = #Predicate<HabitSD> { $0.id == id }
            var d = FetchDescriptor<HabitSD>(predicate: pred)
            d.fetchLimit = 1
            let hit = try ctx.fetch(d).first
            log.info("✅ fetch id=\(id.uuidString, privacy: .public) found=\(hit != nil) in \(elapsedMS(from: t0), privacy: .public) ms")
            return hit.map(HabitMapper.toDomain)
        } catch {
            log.error("❌ fetch id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func save(_ item: HabitModel) throws {
        let t0 = DispatchTime.now()
        log.info("💾 save id=\(item.id.uuidString, privacy: .public) title=\(item.title, privacy: .public)")
        do {
            let ctx = makeContext()
            let sd = HabitMapper.makeSD(from: item)
            ctx.insert(sd)
            try ctx.save()
            log.info("✅ save id=\(item.id.uuidString, privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
        } catch {
            log.error("❌ save id=\(item.id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func update(_ item: HabitModel) throws {
        let t0 = DispatchTime.now()
        log.info("✏️ update id=\(item.id.uuidString, privacy: .public) title=\(item.title, privacy: .public)")
        do {
            let ctx = makeContext()
            let targetId = item.id                               // capture first
            let pred = #Predicate<HabitSD> { $0.id == targetId }
            var d = FetchDescriptor<HabitSD>(predicate: pred)
            d.fetchLimit = 1

            if let sd = try ctx.fetch(d).first {
                HabitMapper.apply(item, to: sd)
                try ctx.save()
                log.info("✅ update id=\(item.id.uuidString, privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
            } else {
                log.warning("⚠️ update skipped (not found) id=\(item.id.uuidString, privacy: .public)")
            }
        } catch {
            log.error("❌ update id=\(item.id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func delete(id: UUID) throws {
        let t0 = DispatchTime.now()
        log.info("🗑️ delete id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let pred = #Predicate<HabitSD> { $0.id == id }
            var d = FetchDescriptor<HabitSD>(predicate: pred)
            d.fetchLimit = 1

            if let sd = try ctx.fetch(d).first {
                // Archive before delete
                let domain = HabitMapper.toDomain(sd)
                let deletedHabit = HabitMapper.makeDeletedSD(from: domain)
                ctx.insert(deletedHabit)

                ctx.delete(sd)
                try ctx.save()
                log.info("✅ delete id=\(id.uuidString, privacy: .public) (archived) in \(elapsedMS(from: t0), privacy: .public) ms")
            } else {
                log.warning("⚠️ delete skipped (not found) id=\(id.uuidString, privacy: .public)")
            }
        } catch {
            log.error("❌ delete id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Deleted Habits
    func fetchAllDeleted() throws -> [HabitModel] {
        let t0 = DispatchTime.now()
        log.info("🧺 fetchAllDeleted start")
        do {
            let ctx = makeContext()
            let descriptor = FetchDescriptor<DeletedHabitSD>(sortBy: [.init(\.deletedAt, order: .reverse)])
            let rows = try ctx.fetch(descriptor)
            let models = rows.map(HabitMapper.deletedToDomain)
            log.info("✅ fetchAllDeleted end sd=\(rows.count) models=\(models.count) in \(elapsedMS(from: t0), privacy: .public) ms")
            return models
        } catch {
            log.error("❌ fetchAllDeleted failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func fetchDeleted(id: UUID) throws -> HabitModel? {
        let t0 = DispatchTime.now()
        log.info("🧺 fetchDeleted id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let pred = #Predicate<DeletedHabitSD> { $0.id == id }
            var d = FetchDescriptor<DeletedHabitSD>(predicate: pred)
            d.fetchLimit = 1
            let hit = try ctx.fetch(d).first
            log.info("✅ fetchDeleted id=\(id.uuidString, privacy: .public) found=\(hit != nil) in \(elapsedMS(from: t0), privacy: .public) ms")
            return hit.map(HabitMapper.deletedToDomain)
        } catch {
            log.error("❌ fetchDeleted id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func permanentlyDeleteDeleted(id: UUID) throws {
        let t0 = DispatchTime.now()
        log.info("🔥 purgeDeleted id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let pred = #Predicate<DeletedHabitSD> { $0.id == id }
            var d = FetchDescriptor<DeletedHabitSD>(predicate: pred)
            d.fetchLimit = 1
            if let sd = try ctx.fetch(d).first {
                ctx.delete(sd)
                try ctx.save()
                log.info("✅ purgeDeleted id=\(id.uuidString, privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
            } else {
                log.warning("⚠️ purgeDeleted skipped (not found) id=\(id.uuidString, privacy: .public)")
            }
        } catch {
            log.error("❌ purgeDeleted id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func restoreDeletedHabit(id: UUID) throws {
        let t0 = DispatchTime.now()
        log.info("♻️ restoreDeleted id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let pred = #Predicate<DeletedHabitSD> { $0.id == id }
            var d = FetchDescriptor<DeletedHabitSD>(predicate: pred)
            d.fetchLimit = 1
            if let deletedSD = try ctx.fetch(d).first {
                let restoredHabit = HabitMapper.deletedToDomain(deletedSD)
                let habitSD = HabitMapper.makeSD(from: restoredHabit)
                ctx.insert(habitSD)
                ctx.delete(deletedSD)
                try ctx.save()
                log.info("✅ restoreDeleted id=\(id.uuidString, privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
            } else {
                log.warning("⚠️ restoreDeleted skipped (not found) id=\(id.uuidString, privacy: .public)")
            }
        } catch {
            log.error("❌ restoreDeleted id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    private var inflightPreset: Task<StatisticsPresetSD?, Error>?
    // MARK: - Statistics Preset
    func fetchStatisticsPreset() async throws -> StatisticsPresetSD? {
            if let t = inflightPreset {            // reuse ongoing work
                return try await t.value
            }
            let t = Task { () throws -> StatisticsPresetSD? in
                let t0 = DispatchTime.now()
                log.info("📊 fetchPreset start")
                defer { log.info("✅ fetchPreset end in \(elapsedMS(from: t0)) ms") }
                let ctx = ModelContext(container)
                let d = FetchDescriptor<StatisticsPresetSD>(sortBy: [SortDescriptor(\.id)])
                return try ctx.fetch(d).first
            }
            inflightPreset = t
            defer { inflightPreset = nil }         // allow a new one after completion
            return try await t.value
        }
//    func fetchStatisticsPreset() async throws -> StatisticsPresetSD? {
//        let t0 = DispatchTime.now()
//        log.info("📊 fetchPreset start")
//        do {
//            let ctx = makeContext()
//            let d = FetchDescriptor<StatisticsPresetSD>(sortBy: [SortDescriptor(\.id)])
//            let first = try ctx.fetch(d).first
//            log.info("✅ fetchPreset end found=\(first != nil) in \(elapsedMS(from: t0), privacy: .public) ms")
//            return first
//        } catch {
//            log.error("❌ fetchPreset failed: \(error.localizedDescription, privacy: .public)")
//            throw error
//        }
//    }

    func saveStatisticsPreset(_ habitIDs: [UUID], presetName: String? = nil) async throws {
        let t0 = DispatchTime.now()
        log.info("💾 savePreset ids=\(habitIDs.count) name=\(presetName ?? "nil", privacy: .public)")
        do {
            let ctx = makeContext()
            let d = FetchDescriptor<StatisticsPresetSD>(sortBy: [SortDescriptor(\.id)])
            if let existing = try ctx.fetch(d).first {
                existing.habitIDs = habitIDs
                existing.presetName = presetName
            } else {
                ctx.insert(StatisticsPresetSD(habitIDs: habitIDs, presetName: presetName))
            }
            try ctx.save()
            log.info("✅ savePreset ok in \(elapsedMS(from: t0), privacy: .public) ms")
        } catch {
            log.error("❌ savePreset failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func deleteStatisticsPreset() async throws {
        let t0 = DispatchTime.now()
        log.info("🗑️ deletePreset start")
        do {
            let ctx = makeContext()
            let d = FetchDescriptor<StatisticsPresetSD>(sortBy: [SortDescriptor(\.id)])
            if let existing = try ctx.fetch(d).first {
                ctx.delete(existing)
                try ctx.save()
                log.info("✅ deletePreset ok in \(elapsedMS(from: t0), privacy: .public) ms")
            } else {
                log.warning("⚠️ deletePreset skipped (not found)")
            }
        } catch {
            log.error("❌ deletePreset failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

extension HabitsRepositorySwiftData {
    func upsert(_ item: HabitModel) throws {
        let t0 = DispatchTime.now()
        log.info("📝 upsert id=\(item.id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let id = item.id
            let pred = #Predicate<HabitSD> { $0.id == id }
            var d = FetchDescriptor<HabitSD>(predicate: pred); d.fetchLimit = 1

            if let sd = try ctx.fetch(d).first {
                HabitMapper.apply(item, to: sd)
            } else {
                ctx.insert(HabitMapper.makeSD(from: item))
            }
            try ctx.save()
            log.info("✅ upsert ok in \(elapsedMS(from: t0), privacy: .public) ms")
        } catch {
            log.error("❌ upsert failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
