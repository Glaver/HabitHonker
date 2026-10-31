//
//  HabitsRepositorySwiftData+Enrollment.swift
//  HabitHonker
//

import Foundation
import SwiftData

// MARK: - Gamification profile enrollment (Phase 4E)
// Staging only. `enrollGamification` calls `stageGamificationEnrollment` on its own context, and the
// call is synchronous: nothing can interleave between these reads and that operation's single save.
// It reads the V1 logical profile, every schedule revision row and, when the store is not enrolled,
// the occurrence, event and ledger row counts. Then it does one of three things:
// - reports an existing enrollment;
// - refuses a state it must not guess about;
// - stages the zero-balance profile and one baseline revision per current Habit, all from the same
//   `trackingStartedAt`.
// Baselines are normalized by the Phase 4B mapper and snapshot rules, exactly like later normal
// revisions. This file never saves and never deletes, merges or repairs a row. It writes no Habit,
// completion record, archive, preset, occurrence, event or ledger row.
extension HabitsRepositorySwiftData {
    func stageGamificationEnrollment(_ request: GamificationEnrollmentRequest,
                                     in ctx: ModelContext) throws -> GamificationEnrollmentResult {
        let policy = try request.schedulingPolicy()
        guard Self.storesGamification(ctx.container.schema) else {
            throw GamificationEnrollmentError.gamificationStorageUnavailable
        }
        let profileKey = BehaviorLogicalIdentity.defaultProfileKey
        let profiles = try ctx.fetch(FetchDescriptor<GamificationProfileSD>(
            predicate: #Predicate<GamificationProfileSD> { $0.logicalProfileKey == profileKey }))
        let revisions = try ctx.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>())

        // The same resolution 4B applies before every Habit mutation. Several physical profiles or
        // orphan history are never resolved by picking a row (4G owns that).
        switch BehaviorScheduleEnrollment.resolve(profiles: profiles.map(BehaviorScheduleRevisionMapper.profileFacts(from:)),
                                                  revisionHistoryExists: { !revisions.isEmpty }) {
        case let .enrolled(stored):
            return try existingEnrollment(profiles[0], stored: stored, revisions: revisions, requested: policy)
        case let .unavailable(conflict):
            throw GamificationEnrollmentError.requiresReconciliation(.scheduleEnrollment(conflict))
        case .notEnrolled:
            break // At most one unenrolled profile row, and no revision rows.
        }
        try requireNoRewardHistory(in: ctx)
        let unenrolledProfile = profiles.isEmpty ? nil : profiles[0]
        if let unenrolledProfile {
            try requireCleanUnenrolledProfile(unenrolledProfile)
        }

        // Stage the profile first, then the baselines. Nothing is saved here.
        let profile: GamificationProfileSD
        if let unenrolledProfile {
            profile = unenrolledProfile // Initialized in place; its physical id is kept.
        } else {
            // Zero projection: the ledger stays the reward authority, and level stays derived.
            profile = GamificationProfileSD(logicalProfileKey: profileKey,
                                            totalXP: 0, honkerCoins: 0,
                                            lifetimeCoinsEarned: 0, lifetimeCoinsSpent: 0,
                                            lastProcessedWeekKey: nil, aggregateFingerprint: nil,
                                            schemaVersion: Self.profileSchemaVersion)
            ctx.insert(profile)
        }
        profile.trackingStartedAt = policy.trackingStartedAt
        profile.schedulingTimeZoneIdentifier = policy.timeZoneIdentifier
        profile.schedulingCalendarIdentifier = policy.calendarIdentifier
        profile.updatedAt = policy.trackingStartedAt

        // One baseline per current Habit row. Archived Habits are not current rows and get none.
        // Every baseline starts at the same store-wide boundary, and none claims earlier history.
        var enrolledTargets = Set<BehaviorTargetID>()
        for habit in try ctx.fetch(FetchDescriptor<HabitSD>()) {
            let snapshot = BehaviorScheduleSnapshot.normalized(BehaviorScheduleRevisionMapper.source(from: habit), policy: policy)
            guard enrolledTargets.insert(snapshot.targetID).inserted else {
                throw GamificationEnrollmentError.requiresReconciliation(.duplicateActiveHabit(snapshot.targetID))
            }
            ctx.insert(BehaviorScheduleRevisionMapper.makeOpenRow(
                logicalRevisionID: BehaviorLogicalIdentity.baselineRevisionID(targetID: snapshot.targetID),
                effectiveFrom: policy.trackingStartedAt,
                snapshot: snapshot))
        }
        return .enrolled(Self.summary(policy, baselineRevisionCount: enrolledTargets.count))
    }

    /// The V1 profile payload version, which Phase 3 also requires.
    private static let profileSchemaVersion = 1

    /// An already enrolled store: reported only when it is coherent enough, and never changed.
    private func existingEnrollment(_ profile: GamificationProfileSD,
                                    stored: BehaviorSchedulingPolicy,
                                    revisions: [BehaviorScheduleRevisionSD],
                                    requested: BehaviorSchedulingPolicy) throws -> GamificationEnrollmentResult {
        guard profile.schemaVersion == Self.profileSchemaVersion else {
            throw GamificationEnrollmentError.requiresReconciliation(.unsupportedProfileSchemaVersion(profile.schemaVersion))
        }
        let predating = revisions.filter { $0.effectiveFrom < stored.trackingStartedAt }.count
        guard predating == 0 else {
            throw GamificationEnrollmentError.requiresReconciliation(.scheduleHistoryPredatesEnrollment(revisionCount: predating))
        }
        let baselines = revisions.filter(Self.isBaseline)
        let misplaced = baselines.filter { $0.effectiveFrom != stored.trackingStartedAt }.count
        guard misplaced == 0 else {
            throw GamificationEnrollmentError.requiresReconciliation(.baselineBoundaryMismatch(revisionCount: misplaced))
        }
        let existing = Self.summary(stored, baselineRevisionCount: baselines.count)
        // The enrollment boundary is frozen: a later instant never moves it, and a different
        // policy is refused, not applied.
        guard stored.timeZoneIdentifier == requested.timeZoneIdentifier,
              stored.calendarIdentifier == requested.calendarIdentifier else {
            throw GamificationEnrollmentError.conflictingExistingEnrollment(existing: existing)
        }
        return .alreadyEnrolled(existing)
    }

    /// Before enrollment no reward history may exist. If it does, enrolling would claim a boundary
    /// that stored rows contradict.
    private func requireNoRewardHistory(in ctx: ModelContext) throws {
        let ledgerEntries = try ctx.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>())
        guard ledgerEntries == 0 else {
            throw GamificationEnrollmentError.requiresReconciliation(.financialHistoryWithoutEnrollment(ledgerEntryCount: ledgerEntries))
        }
        let occurrences = try ctx.fetchCount(FetchDescriptor<TaskOccurrenceSD>())
        let events = try ctx.fetchCount(FetchDescriptor<BehaviorEventSD>())
        guard occurrences == 0, events == 0 else {
            throw GamificationEnrollmentError.requiresReconciliation(.behaviorHistoryWithoutEnrollment(occurrenceCount: occurrences,
                                                                                                        eventCount: events))
        }
    }

    /// A profile row without `trackingStartedAt` is initialized in place only if it is empty.
    /// It is never zeroed.
    private func requireCleanUnenrolledProfile(_ profile: GamificationProfileSD) throws {
        guard profile.schemaVersion == Self.profileSchemaVersion else {
            throw GamificationEnrollmentError.requiresReconciliation(.unsupportedProfileSchemaVersion(profile.schemaVersion))
        }
        guard profile.totalXP == 0, profile.honkerCoins == 0,
              profile.lifetimeCoinsEarned == 0, profile.lifetimeCoinsSpent == 0,
              profile.lastProcessedWeekKey == nil, profile.aggregateFingerprint == nil else {
            throw GamificationEnrollmentError.requiresReconciliation(.nonEmptyUnenrolledProfile)
        }
        guard profile.schedulingTimeZoneIdentifier == nil, profile.schedulingCalendarIdentifier == nil else {
            throw GamificationEnrollmentError.requiresReconciliation(.incompleteExistingEnrollment)
        }
    }

    /// Whether the row is a target's enrollment baseline, recognized by its exact deterministic 4C key.
    private static func isBaseline(_ row: BehaviorScheduleRevisionSD) -> Bool {
        row.logicalRevisionID == BehaviorLogicalIdentity.baselineRevisionID(targetID: BehaviorTargetID(row.targetID))
    }

    /// A store without the V2 gamification models (a V1-only container) cannot hold an enrollment.
    private static func storesGamification(_ schema: Schema) -> Bool {
        schema.entity(for: GamificationProfileSD.self) != nil
            && schema.entity(for: BehaviorScheduleRevisionSD.self) != nil
            && schema.entity(for: TaskOccurrenceSD.self) != nil
            && schema.entity(for: BehaviorEventSD.self) != nil
            && schema.entity(for: GamificationLedgerEntrySD.self) != nil
    }

    private static func summary(_ policy: BehaviorSchedulingPolicy, baselineRevisionCount: Int) -> GamificationEnrollmentSummary {
        GamificationEnrollmentSummary(profileKey: BehaviorLogicalIdentity.defaultProfileKey,
                                      trackingStartedAt: policy.trackingStartedAt,
                                      schedulingTimeZoneIdentifier: policy.timeZoneIdentifier,
                                      schedulingCalendarIdentifier: policy.calendarIdentifier,
                                      baselineRevisionCount: baselineRevisionCount)
    }
}
