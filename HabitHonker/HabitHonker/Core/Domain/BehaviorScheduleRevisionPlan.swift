//
//  BehaviorScheduleRevisionPlan.swift
//  HabitHonker
//

import Foundation

/// A Habit mutation in normalized planning terms, the input of `BehaviorScheduleRevisionPlanning`.
enum BehaviorScheduleMutation: Equatable, Sendable {
    /// A Habit created after enrollment: its first normal revision (never a baseline).
    case create(proposed: BehaviorScheduleSnapshot)
    /// An existing Habit changes from `current` (its definition just before) to `proposed`.
    case update(current: BehaviorScheduleSnapshot, proposed: BehaviorScheduleSnapshot)
    /// An existing Habit is archived/deleted while its definition is `current`.
    case delete(current: BehaviorScheduleSnapshot)
    /// An archived Habit becomes active again with definition `proposed`.
    case restore(proposed: BehaviorScheduleSnapshot)
}

/// One stored physical revision row, as the planner sees it.
struct BehaviorScheduleRevisionFacts: Equatable, Sendable {
    let logicalRevisionID: String
    let effectiveFrom: Date
    let effectiveTo: Date?
    /// The stored planning payload, or nil when it cannot be interpreted as a V1 payload.
    let snapshot: BehaviorScheduleSnapshot?

    var isOpen: Bool { effectiveTo == nil }
}

/// The revision-row effect the persistence transaction stages next to the Habit mutation.
/// Revision IDs for new rows are minted by the caller only for `replaceOpenRevision`/`openRevision`.
enum BehaviorScheduleRevisionPlan: Equatable, Sendable {
    /// History is trustworthy and the planning definition is unchanged: touch no revision row.
    case noRevisionRequired
    /// Close the one open revision at `at` and open a new one from `at` with `next`.
    case replaceOpenRevision(closedRevisionID: String, at: Date, next: BehaviorScheduleSnapshot)
    /// Open a new revision from `at` with `next`; no revision is closed.
    case openRevision(at: Date, next: BehaviorScheduleSnapshot)
    /// Close the one open revision at `at`; no revision is opened.
    case closeOpenRevision(closedRevisionID: String, at: Date)
    /// Leave every revision row untouched.
    case deferHistory(BehaviorScheduleHistoryConflict)
}
