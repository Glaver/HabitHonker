//
//  GamificationEnrollmentRequest.swift
//  HabitHonker
//

import Foundation

/// An explicit request to begin gamification tracking for one durable store (Phase 4E).
///
/// Every input comes from the caller. Enrollment reads no clock, no device time zone and no device
/// calendar. `enrolledAt` becomes the store's `trackingStartedAt` and the `effectiveFrom` of every
/// baseline revision. The time zone and calendar become the store's fixed V1 scheduling policy.
struct GamificationEnrollmentRequest: Equatable, Sendable {
    let enrolledAt: Date
    /// An explicit `TimeZone` identifier, for example `America/Los_Angeles`. There is no fallback.
    let schedulingTimeZoneIdentifier: String
    /// V1 accepts only `BehaviorSchedulingPolicy.gregorianCalendarIdentifier`.
    let schedulingCalendarIdentifier: String

    init(enrolledAt: Date,
         schedulingTimeZoneIdentifier: String,
         schedulingCalendarIdentifier: String = BehaviorSchedulingPolicy.gregorianCalendarIdentifier) {
        self.enrolledAt = enrolledAt
        self.schedulingTimeZoneIdentifier = schedulingTimeZoneIdentifier
        self.schedulingCalendarIdentifier = schedulingCalendarIdentifier
    }

    /// The scheduling policy this request would establish.
    ///
    /// It is validated by the same Phase 4B resolution that reads an enrolled profile, so a policy
    /// accepted here always resolves again from the stored profile. The baselines are then normalized
    /// exactly like later normal revisions.
    /// Throws `invalidSchedulingTimeZone` or `unsupportedSchedulingCalendar`; nothing falls back.
    func schedulingPolicy() throws -> BehaviorSchedulingPolicy {
        let proposed = BehaviorScheduleProfileFacts(trackingStartedAt: enrolledAt,
                                                    schedulingTimeZoneIdentifier: schedulingTimeZoneIdentifier,
                                                    schedulingCalendarIdentifier: schedulingCalendarIdentifier)
        switch BehaviorScheduleEnrollment.resolve(profiles: [proposed], revisionHistoryExists: { false }) {
        case let .enrolled(policy):
            return policy
        case .unavailable(.invalidSchedulingTimeZone):
            throw GamificationEnrollmentError.invalidSchedulingTimeZone(schedulingTimeZoneIdentifier)
        case .unavailable(.unsupportedSchedulingCalendar):
            throw GamificationEnrollmentError.unsupportedSchedulingCalendar(schedulingCalendarIdentifier)
        case .notEnrolled, .unavailable:
            // Unreachable: one profile with a tracking start resolves only to a policy or to one of
            // the two policy errors above.
            preconditionFailure("enrollment facts with a tracking start resolved to neither a policy nor a policy error")
        }
    }
}
