//
//  GamificationEnrollmentServicing.swift
//  HabitHonker
//

import Foundation

/// The explicit application command that begins gamification tracking for the current store (Phase 4E).
///
/// Nothing calls it automatically: not app launch, dependency construction, store opening, Habit
/// creation or completion. A future product flow decides when to call it.
protocol GamificationEnrollmentServicing: Sendable {
    /// Enrolls the store once. A repeated call with the same time zone and calendar returns
    /// `.alreadyEnrolled` and writes nothing. Refusals throw `GamificationEnrollmentError`; a failing
    /// save rethrows the persistence error, and in either case the store is unchanged.
    func enroll(_ request: GamificationEnrollmentRequest) async throws -> GamificationEnrollmentResult
}
