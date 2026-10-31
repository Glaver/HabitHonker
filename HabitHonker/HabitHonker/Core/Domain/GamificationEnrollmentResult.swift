//
//  GamificationEnrollmentResult.swift
//  HabitHonker
//

import Foundation

/// The enrollment of one durable store as plain values (Phase 4E). No persistence object leaks out.
struct GamificationEnrollmentSummary: Equatable, Sendable {
    /// Always `BehaviorLogicalIdentity.defaultProfileKey` in V1.
    let profileKey: String
    let trackingStartedAt: Date
    let schedulingTimeZoneIdentifier: String
    let schedulingCalendarIdentifier: String
    /// Baseline revision rows (`rev:v1:<target>:baseline`). For `.enrolled`, the rows just written;
    /// for `.alreadyEnrolled` or a policy conflict, the rows found in the store.
    let baselineRevisionCount: Int
}

/// A successful enrollment call (Phase 4E). Refusals are thrown as `GamificationEnrollmentError`.
enum GamificationEnrollmentResult: Equatable, Sendable {
    /// Tracking begins now. The zero-balance profile and one baseline per active Habit were saved together.
    case enrolled(GamificationEnrollmentSummary)
    /// The store was already enrolled under the requested time zone and calendar. Nothing was written,
    /// and the existing `trackingStartedAt` stands even if the request carried a later instant.
    case alreadyEnrolled(GamificationEnrollmentSummary)

    var summary: GamificationEnrollmentSummary {
        switch self {
        case let .enrolled(summary), let .alreadyEnrolled(summary):
            return summary
        }
    }
}
