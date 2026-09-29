//
//  BehaviorScheduleRevisionPlanning.swift
//  HabitHonker
//

import Foundation

/// Pure schedule-revision planning (Phase 4B).
///
/// Decides, from normalized snapshots and the target's stored revision rows, whether a Habit
/// mutation extends history, needs no revision, or must defer history. It reads no clock, mints no
/// identifier, touches no persistence and computes no reward: the caller supplies `effectiveAt`,
/// mints revision IDs only for planned inserts, and stages the plan in its own transaction.
protocol BehaviorScheduleRevisionPlanning: Sendable {
    /// True when the planning payloads differ, i.e. the change is revision-relevant.
    func requiresRevision(current: BehaviorScheduleSnapshot, proposed: BehaviorScheduleSnapshot) -> Bool

    /// - Parameters:
    ///   - history: every stored revision row of the mutation's target, in any order.
    ///   - trackingStartedAt: the enrolled profile's history start.
    ///   - effectiveAt: the mutation instant captured at the application boundary.
    func plan(_ mutation: BehaviorScheduleMutation,
              history: [BehaviorScheduleRevisionFacts],
              trackingStartedAt: Date,
              effectiveAt: Date) -> BehaviorScheduleRevisionPlan
}
