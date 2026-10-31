//
//  GamificationEnrollmentRepositoryProtocol.swift
//  HabitHonker
//

import Foundation

/// The atomic, store-wide enrollment write (Phase 4E).
///
/// An implementation reads the profile, schedule history and current Habits, and then either reports
/// an existing enrollment, refuses the stored state, or writes the zero-balance profile and every
/// baseline revision together, in one save.
protocol GamificationEnrollmentRepositoryProtocol: Sendable {
    func enroll(_ request: GamificationEnrollmentRequest) async throws -> GamificationEnrollmentResult
}
