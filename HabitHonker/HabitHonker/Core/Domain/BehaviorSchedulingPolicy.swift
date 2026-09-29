//
//  BehaviorSchedulingPolicy.swift
//  HabitHonker
//

import Foundation

/// The fixed scheduling policy of the one enrolled V1 gamification profile (Phase 4B).
///
/// Only `BehaviorScheduleEnrollment.resolve` creates a value, so every policy has a real enrollment
/// instant, a valid time zone and the V1 Gregorian calendar. Schedule snapshots are always
/// normalized under this policy and never under the device's own calendar, time zone or locale.
struct BehaviorSchedulingPolicy: Equatable, Sendable {
    /// The V1 persisted calendar representation established by Phase 2 (Foundation's Gregorian
    /// identifier text). Revisions and profiles store exactly this text.
    static let gregorianCalendarIdentifier = "gregorian"

    /// The profile's `trackingStartedAt`: official schedule history starts here.
    let trackingStartedAt: Date
    /// The profile's scheduling time zone identifier, exactly as stored.
    let timeZoneIdentifier: String
    let timeZone: TimeZone

    var calendarIdentifier: String { Self.gregorianCalendarIdentifier }

    /// Gregorian calendar fixed to the policy time zone (POSIX locale).
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    fileprivate init(trackingStartedAt: Date, timeZoneIdentifier: String, timeZone: TimeZone) {
        self.trackingStartedAt = trackingStartedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.timeZone = timeZone
    }
}

/// The enrollment facts of one physical profile row of the V1 logical profile.
struct BehaviorScheduleProfileFacts: Equatable, Sendable {
    var trackingStartedAt: Date?
    var schedulingTimeZoneIdentifier: String?
    var schedulingCalendarIdentifier: String?
}

/// Whether schedule history may be written, read from stored profile facts only (Phase 4B).
/// 4B reads the profile; it never creates, normalizes or repairs one.
enum BehaviorScheduleEnrollment: Equatable, Sendable {
    /// No enrollment and no schedule history: Habit mutations write no revisions.
    case notEnrolled
    /// Exactly one enrolled profile row with a usable policy.
    case enrolled(BehaviorSchedulingPolicy)
    /// Enrollment state is ambiguous or unusable; history must be deferred.
    case unavailable(BehaviorScheduleHistoryConflict)

    /// - Parameters:
    ///   - profiles: every physical row of the logical profile `profile:v1:default`.
    ///   - revisionHistoryExists: asked only when no row is enrolled, to tell "not enrolled"
    ///     from schedule history that exists without an enrollment.
    static func resolve(profiles: [BehaviorScheduleProfileFacts],
                        revisionHistoryExists: () throws -> Bool) rethrows -> BehaviorScheduleEnrollment {
        switch profiles.count {
        case 0:
            return try revisionHistoryExists() ? .unavailable(.orphanRevisionHistory) : .notEnrolled
        case 1:
            break
        default:
            // Several physical rows before 4G reconciliation: never pick one.
            return .unavailable(.multipleProfiles(count: profiles.count))
        }
        let profile = profiles[0]
        guard let trackingStartedAt = profile.trackingStartedAt else {
            return try revisionHistoryExists() ? .unavailable(.orphanRevisionHistory) : .notEnrolled
        }
        guard let identifier = profile.schedulingTimeZoneIdentifier,
              let timeZone = TimeZone(identifier: identifier) else {
            return .unavailable(.invalidSchedulingTimeZone(profile.schedulingTimeZoneIdentifier))
        }
        guard profile.schedulingCalendarIdentifier == BehaviorSchedulingPolicy.gregorianCalendarIdentifier else {
            return .unavailable(.unsupportedSchedulingCalendar(profile.schedulingCalendarIdentifier))
        }
        return .enrolled(BehaviorSchedulingPolicy(trackingStartedAt: trackingStartedAt,
                                                  timeZoneIdentifier: identifier,
                                                  timeZone: timeZone))
    }
}
