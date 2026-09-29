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
    /// Phase 4B: pure schedule-revision planning, called synchronously inside Habit mutations.
    let scheduleRevisionPlanner: any BehaviorScheduleRevisionPlanning
    /// Phase 4B: mints normal revision IDs, only for revisions a mutation actually inserts.
    let scheduleRevisionIDs: any BehaviorScheduleRevisionIDProviding
    #if DEBUG
    /// Test seam, absent from release builds: runs after a Habit mutation has staged its whole
    /// write set and right before its single save. Throwing discards the context unsaved.
    private var beforeCommitForTesting: (@Sendable (ModelContext) throws -> Void)?
    #endif

    init(container: ModelContainer,
         scheduleRevisionPlanner: any BehaviorScheduleRevisionPlanning = BehaviorScheduleRevisionPlanner(),
         scheduleRevisionIDs: any BehaviorScheduleRevisionIDProviding = BehaviorScheduleRevisionIDProviderV1()) {
        self.container = container
        self.scheduleRevisionPlanner = scheduleRevisionPlanner
        self.scheduleRevisionIDs = scheduleRevisionIDs
        log.info("📦 Repo init with container: \(String(describing: container), privacy: .public)")
    }

    #if DEBUG
    func setBeforeCommitForTesting(_ hook: (@Sendable (ModelContext) throws -> Void)?) {
        beforeCommitForTesting = hook
    }
    #endif

    // MARK: - Helpers
    private func makeContext() -> ModelContext {
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return ctx
    }

    // MARK: - Isolated normalized completion (not called by the live HabitService)
    func completeBehavior(_ command: BehaviorCompletionCommand,
                          transaction: BehaviorTransactionSD) throws -> BehaviorTransactionResult {
        try executeBehavior(command, transaction: transaction, beforeSave: { _ in })
    }

    #if DEBUG
    /// Internal test seam, absent from release builds. The same save/rollback path is exercised.
    func completeBehaviorForTesting(_ command: BehaviorCompletionCommand,
                                    transaction: BehaviorTransactionSD,
                                    beforeSave: @Sendable (ModelContext) throws -> Void) throws -> BehaviorTransactionResult {
        try executeBehavior(command, transaction: transaction, beforeSave: beforeSave)
    }
    #endif

    private func executeBehavior(_ command: BehaviorCompletionCommand,
                                 transaction: BehaviorTransactionSD,
                                 beforeSave: (ModelContext) throws -> Void) throws -> BehaviorTransactionResult {
        let context = makeContext()
        do {
            let result = try transaction.apply(command, in: context)
            if case .applied = result {
                try beforeSave(context)
                try context.save()
            }
            return result
        } catch {
            context.rollback()
            if let error = error as? BehaviorTransactionError { throw error }
            if let error = error as? GamificationCalculationError {
                throw BehaviorTransactionError.calculationFailure(error)
            }
            let underlying = error as NSError
            throw BehaviorTransactionError.persistenceFailure(domain: underlying.domain, code: underlying.code,
                                                                message: underlying.localizedDescription)
        }
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

    /// Archives and deletes the habit. After enrollment its open schedule revision is closed at
    /// `effectiveAt` in the same save (Phase 4B); unsafe history is deferred and never blocks the
    /// delete. Returns nil, writing nothing, when no active habit has this id.
    @discardableResult
    func delete(id: UUID, effectiveAt: Date) throws -> ScheduleHistoryOutcome? {
        let t0 = DispatchTime.now()
        log.info("🗑️ delete id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let pred = #Predicate<HabitSD> { $0.id == id }
            var d = FetchDescriptor<HabitSD>(predicate: pred)
            d.fetchLimit = 1

            if let sd = try ctx.fetch(d).first {
                let history = try stageScheduleHistory(.deleted(BehaviorScheduleRevisionMapper.source(from: sd)),
                                                       effectiveAt: effectiveAt, in: ctx)
                // Archive before delete
                let domain = HabitMapper.toDomain(sd)
                let deletedHabit = HabitMapper.makeDeletedSD(from: domain)
                ctx.insert(deletedHabit)

                ctx.delete(sd)
                try commit(ctx)
                log.info("✅ delete id=\(id.uuidString, privacy: .public) (archived) history=\(String(describing: history), privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
                return history
            } else {
                log.warning("⚠️ delete skipped (not found) id=\(id.uuidString, privacy: .public)")
                return nil
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

    /// Restores an archived habit. After enrollment a new normal schedule revision opens at
    /// `effectiveAt` in the same save (Phase 4B); an old closed revision is never reopened, and
    /// unsafe history is deferred without blocking the restore. Returns nil, writing nothing, when
    /// no archived habit has this id.
    @discardableResult
    func restoreDeletedHabit(id: UUID, effectiveAt: Date) throws -> ScheduleHistoryOutcome? {
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
                let history = try stageScheduleHistory(.restored(BehaviorScheduleRevisionMapper.source(from: habitSD)),
                                                       effectiveAt: effectiveAt, in: ctx)
                try commit(ctx)
                log.info("✅ restoreDeleted id=\(id.uuidString, privacy: .public) history=\(String(describing: history), privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
                return history
            } else {
                log.warning("⚠️ restoreDeleted skipped (not found) id=\(id.uuidString, privacy: .public)")
                return nil
            }
        } catch {
            log.error("❌ restoreDeleted id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    // MARK: - Statistics Preset
    func fetchStatisticsPresetHabitIDs() throws -> [UUID]? {
        let t0 = DispatchTime.now()
        log.info("📊 fetchPresetHabitIDs start")
        defer { log.info("✅ fetchPresetHabitIDs end in \(elapsedMS(from: t0)) ms") }

        let ctx = makeContext()
        let d = FetchDescriptor<StatisticsPresetSD>(sortBy: [SortDescriptor(\.id)])
        return try ctx.fetch(d).first?.habitIDs
    }

    func saveStatisticsPreset(_ habitIDs: [UUID], presetName: String? = nil) async throws {
        let t0 = DispatchTime.now()
        log.info("💾 savePreset ids=\(habitIDs.count) name=\(presetName ?? "nil", privacy: .public)")

        do {
            let ctx = makeContext()
            let d = FetchDescriptor<StatisticsPresetSD>(sortBy: [SortDescriptor(\.id)])

            if let existing = try ctx.fetch(d).first {
                existing.habitIDs = habitIDs
                if let presetName { existing.name = presetName }      // ← presetName → name
            } else {
                // ← правильный init: name / isActive / habitIDs
                let preset = StatisticsPresetSD(name: presetName ?? "", isActive: true, habitIDs: habitIDs)
                ctx.insert(preset)
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

// MARK: - Metadata-safe mutations (Phase 4A) and their schedule history (Phase 4B)
// Metadata writes never read, assign or recreate `records`. Completion history changes only
// through `recordLegacyCompletion`. Each operation uses one context and one save, and runs
// entirely inside this actor, so no other write can interleave between its read and its save.
// Phase 4B: create/metadata/priority (and delete/restore above) also stage their schedule-history
// effect (`stageScheduleHistory`, in HabitsRepositorySwiftData+ScheduleHistory.swift) on the same
// context, synchronously, before that single save. Before enrollment nothing is staged. Unsafe
// history is deferred and reported, never allowed to block the Habit mutation. `effectiveAt` is
// the mutation instant captured by the application boundary; this actor never reads a clock for it.
// `recordLegacyCompletion` has no schedule-history effect.
extension HabitsRepositorySwiftData {
    /// Inserts a brand-new habit with no completion history and, after enrollment, its first
    /// normal schedule revision from `effectiveAt` in the same save.
    /// Throws `alreadyExists` instead of overwriting an existing row.
    func createHabit(id: UUID, metadata: HabitMetadata, effectiveAt: Date) throws -> HabitMutationResult {
        let t0 = DispatchTime.now()
        log.info("🆕 createHabit id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            guard try activeHabitCount(id: id, in: ctx) == 0 else {
                throw HabitRepositoryError.alreadyExists(id)
            }
            let sd = HabitMapper.makeSD(id: id, metadata: metadata)
            ctx.insert(sd)
            let history = try stageScheduleHistory(.created(BehaviorScheduleRevisionMapper.source(from: sd)),
                                                   effectiveAt: effectiveAt, in: ctx)
            try commit(ctx)
            log.info("✅ createHabit id=\(id.uuidString, privacy: .public) history=\(String(describing: history), privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
            return HabitMutationResult(habit: HabitMapper.toDomain(sd), scheduleHistory: history)
        } catch {
            log.error("❌ createHabit id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Replaces the editable fields of an existing habit and returns the fresh persisted model,
    /// including its current (authoritative) records. Throws `notFound`; never inserts.
    /// After enrollment a revision-relevant change closes the open schedule revision and opens the
    /// next one at `effectiveAt` in the same save; other changes leave revision history untouched.
    func updateMetadata(id: UUID, metadata: HabitMetadata, effectiveAt: Date) throws -> HabitMutationResult {
        let t0 = DispatchTime.now()
        log.info("✏️ updateMetadata id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let sd = try activeHabit(id: id, in: ctx)
            let before = BehaviorScheduleRevisionMapper.source(from: sd)
            HabitMapper.applyMetadata(metadata, to: sd)
            let history = try stageScheduleHistory(.updated(before: before, after: BehaviorScheduleRevisionMapper.source(from: sd)),
                                                   effectiveAt: effectiveAt, in: ctx)
            try commit(ctx)
            log.info("✅ updateMetadata id=\(id.uuidString, privacy: .public) history=\(String(describing: history), privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
            return HabitMutationResult(habit: HabitMapper.toDomain(sd), scheduleHistory: history)
        } catch {
            log.error("❌ updateMetadata id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Changes only the priority. Throws `notFound`; never inserts.
    /// Priority is revision-relevant: after enrollment a real change closes/opens schedule history
    /// at `effectiveAt` in the same save.
    func updatePriority(id: UUID, priority: PriorityEisenhower, effectiveAt: Date) throws -> HabitMutationResult {
        let t0 = DispatchTime.now()
        log.info("🎯 updatePriority id=\(id.uuidString, privacy: .public) priority=\(priority.rawValue, privacy: .public)")
        do {
            let ctx = makeContext()
            let sd = try activeHabit(id: id, in: ctx)
            let before = BehaviorScheduleRevisionMapper.source(from: sd)
            sd.priorityRaw = priority.rawValue
            let history = try stageScheduleHistory(.updated(before: before, after: BehaviorScheduleRevisionMapper.source(from: sd)),
                                                   effectiveAt: effectiveAt, in: ctx)
            try commit(ctx)
            log.info("✅ updatePriority id=\(id.uuidString, privacy: .public) history=\(String(describing: history), privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
            return HabitMutationResult(habit: HabitMapper.toDomain(sd), scheduleHistory: history)
        } catch {
            log.error("❌ updatePriority id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Legacy same-day completion (the former `HabitModel.completeHabitNow` semantics) in one
    /// actor operation. The record whose date falls on the same `calendar` day as `date` is
    /// incremented with checked arithmetic, keeping its id and original timestamp; if there is
    /// none, a record with count 1 is inserted at `date`. Metadata is not touched.
    ///
    /// Several records on that one day (a legacy/sync anomaly) are not merged or deleted: the
    /// earliest one (then smallest UUID string) is incremented, deterministically.
    func recordLegacyCompletion(id: UUID, at date: Date, calendar: Calendar) throws -> HabitModel {
        let t0 = DispatchTime.now()
        log.info("✔️ recordLegacyCompletion id=\(id.uuidString, privacy: .public)")
        do {
            let ctx = makeContext()
            let sd = try activeHabit(id: id, in: ctx)
            let records = sd.records ?? []
            let sameDay = records
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
            if let record = sameDay.first {
                let (next, overflow) = record.count.addingReportingOverflow(1)
                guard !overflow else { throw HabitRepositoryError.completionCountOverflow(id) }
                record.count = next
            } else {
                let record = HabitRecordSD(date: date, count: 1, habit: sd)
                ctx.insert(record)
                sd.records = records + [record]
            }
            try ctx.save()
            log.info("✅ recordLegacyCompletion id=\(id.uuidString, privacy: .public) sameDay=\(sameDay.count, privacy: .public) in \(elapsedMS(from: t0), privacy: .public) ms")
            return HabitMapper.toDomain(sd)
        } catch {
            log.error("❌ recordLegacyCompletion id=\(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// The single save of every Habit metadata/lifecycle mutation.
    private func commit(_ ctx: ModelContext) throws {
        #if DEBUG
        try beforeCommitForTesting?(ctx)
        #endif
        try ctx.save()
    }

    private func activeHabitCount(id: UUID, in ctx: ModelContext) throws -> Int {
        try ctx.fetchCount(FetchDescriptor<HabitSD>(predicate: #Predicate<HabitSD> { $0.id == id }))
    }

    /// Same lookup rule as `fetch(id:)`; missing rows become a typed `notFound`.
    private func activeHabit(id: UUID, in ctx: ModelContext) throws -> HabitSD {
        var descriptor = FetchDescriptor<HabitSD>(predicate: #Predicate<HabitSD> { $0.id == id })
        descriptor.fetchLimit = 1
        guard let sd = try ctx.fetch(descriptor).first else {
            throw HabitRepositoryError.notFound(id)
        }
        return sd
    }
}
