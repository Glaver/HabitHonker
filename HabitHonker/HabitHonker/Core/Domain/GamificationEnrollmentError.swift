//
//  GamificationEnrollmentError.swift
//  HabitHonker
//

import Foundation

/// Why an enrollment request was refused (Phase 4E). Every refusal writes nothing.
/// A failing save is not listed here: it is rethrown as the underlying persistence error.
enum GamificationEnrollmentError: Error, Equatable, Sendable {
    /// The store is not durable (`ephemeralFallback`), so progress must not look durable.
    case storageNotDurable(StorageDurabilityState)
    /// The requested time zone is not a valid `TimeZone` identifier. There is no fallback.
    case invalidSchedulingTimeZone(String)
    /// The requested calendar is not the V1 Gregorian representation. There is no fallback.
    case unsupportedSchedulingCalendar(String)
    /// The store's schema has no gamification models, so it cannot hold an enrollment.
    case gamificationStorageUnavailable
    /// The store is already enrolled under a different time zone or calendar. That policy is frozen
    /// and is not changed.
    case conflictingExistingEnrollment(existing: GamificationEnrollmentSummary)
    /// Stored state contradicts a clean enrollment boundary. 4E does not guess, repair or merge.
    /// Phase 4G reconciliation, or manual handling, owns these states.
    case requiresReconciliation(GamificationEnrollmentConflict)
}

/// A stored state that enrollment refuses to build on (Phase 4E).
enum GamificationEnrollmentConflict: Equatable, Sendable {
    /// The stored profile and schedule history do not resolve to one usable enrollment, in the Phase 4B
    /// vocabulary:
    /// - `multipleProfiles`: several physical rows of `profile:v1:default`;
    /// - `orphanRevisionHistory`: revision rows exist without an enrolled profile;
    /// - `invalidSchedulingTimeZone` / `unsupportedSchedulingCalendar`: an enrolled profile whose
    ///   stored policy is unusable.
    case scheduleEnrollment(BehaviorScheduleHistoryConflict)
    /// Ledger rows exist although no profile is enrolled.
    case financialHistoryWithoutEnrollment(ledgerEntryCount: Int)
    /// Occurrence or behavior-event rows exist although no profile is enrolled.
    case behaviorHistoryWithoutEnrollment(occurrenceCount: Int, eventCount: Int)
    /// The one profile row has no `trackingStartedAt` but carries balances, lifetime totals,
    /// a processed week or an aggregate fingerprint.
    case nonEmptyUnenrolledProfile
    /// The one profile row has no `trackingStartedAt` but already carries part of a scheduling policy.
    case incompleteExistingEnrollment
    /// The profile row's payload version is not the V1 version that enrollment and Phase 3 read.
    case unsupportedProfileSchemaVersion(Int)
    /// The profile is enrolled, but revision rows start before its `trackingStartedAt`.
    case scheduleHistoryPredatesEnrollment(revisionCount: Int)
    /// The profile is enrolled, but baseline rows do not start exactly at its `trackingStartedAt`.
    case baselineBoundaryMismatch(revisionCount: Int)
    /// Several physical current-Habit rows share one target ID, so one baseline cannot describe it.
    case duplicateActiveHabit(BehaviorTargetID)
}
