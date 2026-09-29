//
//  BehaviorScheduleRevisionIDProviding.swift
//  HabitHonker
//

import Foundation

/// Mints the logical ID of a normal (post-enrollment) schedule revision (Phase 4B).
///
/// Called once per revision that is actually inserted; never for no-op or deferred mutations.
/// Enrollment baselines use the deterministic 4C key instead (`BehaviorLogicalIdentity`).
protocol BehaviorScheduleRevisionIDProviding: Sendable {
    /// `rev:v1:<target uuid>:change:<revision uuid>`, both UUIDs lowercase canonical text.
    func makeRevisionID(targetID: BehaviorTargetID) -> String
}
