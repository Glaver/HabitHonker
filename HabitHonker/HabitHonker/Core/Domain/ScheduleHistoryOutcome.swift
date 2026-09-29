//
//  ScheduleHistoryOutcome.swift
//  HabitHonker
//

import Foundation

/// What a Habit mutation did to schedule revision history (Phase 4B).
///
/// Operational diagnostic output, never persisted: the Habit mutation itself was saved in every
/// case. A persistence failure is a thrown error, not an outcome. Phase 4G derives a target's
/// cutover safety from stored state, not from this value.
enum ScheduleHistoryOutcome: Equatable, Sendable {
    /// No enrolled profile and no schedule history: no revision is claimed.
    case notEnrolled
    /// History is trustworthy and the planning definition did not change.
    case revisionNotRequired
    /// Revision rows were closed and/or opened in the same save as the Habit mutation.
    case revisionApplied(ScheduleRevisionChange)
    /// History could not be extended safely. Revision rows are untouched and nothing was fabricated;
    /// the target is derivably not cutover-safe until 4G reconciles or repairs it.
    case revisionDeferred(BehaviorScheduleHistoryConflict)
}

/// The revision rows one mutation closed and/or opened, all at `effectiveAt`.
/// Intervals are half-open `[effectiveFrom, effectiveTo)`, so `effectiveAt` belongs to the opened revision.
struct ScheduleRevisionChange: Equatable, Sendable {
    /// Logical ID of the revision whose `effectiveTo` became `effectiveAt`.
    let closedRevisionID: String?
    /// Logical ID of the revision inserted with `effectiveFrom = effectiveAt`, `effectiveTo = nil`.
    let openedRevisionID: String?
    let effectiveAt: Date
}

/// Why schedule history was deferred. Each case is a concrete stored state; none is a save failure.
enum BehaviorScheduleHistoryConflict: Equatable, Sendable {
    /// More than one physical row exists for `profile:v1:default`. 4B never picks one (4G does).
    case multipleProfiles(count: Int)
    /// The enrolled profile's scheduling time zone is missing or not a valid identifier.
    case invalidSchedulingTimeZone(String?)
    /// The enrolled profile's scheduling calendar is missing or not the V1 Gregorian calendar.
    case unsupportedSchedulingCalendar(String?)
    /// Schedule revision rows exist although no profile row is enrolled.
    case orphanRevisionHistory
    /// The mutation instant is earlier than `trackingStartedAt`.
    case mutationPredatesEnrollment(trackingStartedAt: Date, effectiveAt: Date)
    /// An existing enrolled Habit has no open revision.
    case missingOpenRevision
    /// Several physical open revisions exist for the target, even if they look identical.
    case multipleOpenRevisions(count: Int)
    /// A new or restored Habit already has an open revision.
    case openRevisionAlreadyExists
    /// The open revision does not describe the Habit as it was just before this mutation.
    case currentRevisionDoesNotMatchCurrentHabit
    /// The mutation instant is earlier than a boundary already recorded in the target's history.
    case revisionChronologyConflict(latestBoundary: Date, effectiveAt: Date)
}
