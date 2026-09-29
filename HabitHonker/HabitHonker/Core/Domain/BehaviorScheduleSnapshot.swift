//
//  BehaviorScheduleSnapshot.swift
//  HabitHonker
//

import Foundation

/// The revision-relevant facts of a Habit's current definition, before normalization (Phase 4B).
///
/// Built from the persisted current Habit row. It carries no title, description, tags, icon color,
/// completion history or gamification state: changing only those can never require a revision.
struct BehaviorScheduleSource: Equatable, Sendable {
    var targetID: BehaviorTargetID
    var taskType: GamificationTaskType
    var weekdays: Set<BehaviorWeekday>
    /// The one-time due instant; for a repeating Habit, the instant whose clock is the reminder time.
    var dueDate: Date
    var notificationEnabled: Bool
    var priority: BehaviorPriority
    var iconName: String?
}

/// The historical planning definition stored in one schedule revision (Phase 4B).
///
/// Equality compares the planning payload only. Physical row identity, logical revision identity,
/// the validity interval and row schema bookkeeping are deliberately not part of this value.
/// Values built by `normalized(_:policy:)` follow the V1 normalization rules; a value decoded from
/// storage may not, and then it simply compares unequal.
struct BehaviorScheduleSnapshot: Equatable, Sendable {
    var targetID: BehaviorTargetID
    var taskType: GamificationTaskType
    /// Bit 0 = Sunday ... bit 6 = Saturday, i.e. `1 << (weekday raw value - 1)`. Always 0 for one-time.
    var selectedWeekdaysMask: Int
    /// Local clock in the scheduling time zone. Non-nil only for a repeating Habit with an explicit
    /// timed commitment (V1 proxy: notification enabled).
    var scheduledHour: Int?
    var scheduledMinute: Int?
    /// The one-time due instant. Always nil for repeating.
    var dueAt: Date?
    var schedulingTimeZoneIdentifier: String
    var schedulingCalendarIdentifier: String
    var priority: BehaviorPriority
    var iconName: String?
    var notificationEnabled: Bool
}

extension BehaviorScheduleSnapshot {
    /// Frozen V1 weekday mask: bit `raw - 1` for every weekday (Sunday = raw 1 = bit 0).
    /// A bitwise OR over the elements, so neither iteration order nor duplicates can change it,
    /// and no locale or calendar display order takes part.
    static func weekdayMask<Weekdays: Sequence>(_ weekdays: Weekdays) -> Int where Weekdays.Element == BehaviorWeekday {
        weekdays.reduce(0) { mask, weekday in mask | (1 << (weekday.rawValue - 1)) }
    }

    /// Normalizes current Habit facts under the enrolled profile's fixed scheduling policy.
    ///
    /// - Repeating: weekday mask; no due instant; hour/minute of `dueDate` read in the policy time
    ///   zone on the Gregorian calendar when notifications are on, otherwise nil, so a stored but
    ///   unused clock never produces history.
    /// - One-time: mask 0, no clock, `dueAt = dueDate` (kept even when notifications are off; timing
    ///   reward eligibility is decided later, not here).
    /// - Priority, icon name and notification state are copied exactly.
    static func normalized(_ source: BehaviorScheduleSource, policy: BehaviorSchedulingPolicy) -> BehaviorScheduleSnapshot {
        switch source.taskType {
        case .repeating:
            let clock = source.notificationEnabled
                ? policy.calendar.dateComponents([.hour, .minute], from: source.dueDate)
                : nil
            return BehaviorScheduleSnapshot(targetID: source.targetID,
                                            taskType: .repeating,
                                            selectedWeekdaysMask: weekdayMask(source.weekdays),
                                            scheduledHour: clock?.hour,
                                            scheduledMinute: clock?.minute,
                                            dueAt: nil,
                                            schedulingTimeZoneIdentifier: policy.timeZoneIdentifier,
                                            schedulingCalendarIdentifier: policy.calendarIdentifier,
                                            priority: source.priority,
                                            iconName: source.iconName,
                                            notificationEnabled: source.notificationEnabled)
        case .oneTime:
            return BehaviorScheduleSnapshot(targetID: source.targetID,
                                            taskType: .oneTime,
                                            selectedWeekdaysMask: 0,
                                            scheduledHour: nil,
                                            scheduledMinute: nil,
                                            dueAt: source.dueDate,
                                            schedulingTimeZoneIdentifier: policy.timeZoneIdentifier,
                                            schedulingCalendarIdentifier: policy.calendarIdentifier,
                                            priority: source.priority,
                                            iconName: source.iconName,
                                            notificationEnabled: source.notificationEnabled)
        }
    }
}

/// A current-Habit mutation described by its revision-relevant facts.
enum BehaviorScheduleSourceChange: Equatable, Sendable {
    /// A brand-new Habit row was inserted.
    case created(BehaviorScheduleSource)
    /// An existing Habit's definition changed (metadata or priority): facts before and after.
    case updated(before: BehaviorScheduleSource, after: BehaviorScheduleSource)
    /// An existing Habit was archived/deleted: its facts just before.
    case deleted(BehaviorScheduleSource)
    /// An archived Habit became active again: its restored facts.
    case restored(BehaviorScheduleSource)

    var targetID: BehaviorTargetID {
        switch self {
        case let .created(source), let .deleted(source), let .restored(source):
            return source.targetID
        case let .updated(before, _):
            return before.targetID
        }
    }

    /// The same change expressed in normalized snapshots under `policy`.
    func normalized(under policy: BehaviorSchedulingPolicy) -> BehaviorScheduleMutation {
        switch self {
        case let .created(source):
            return .create(proposed: .normalized(source, policy: policy))
        case let .updated(before, after):
            return .update(current: .normalized(before, policy: policy), proposed: .normalized(after, policy: policy))
        case let .deleted(source):
            return .delete(current: .normalized(source, policy: policy))
        case let .restored(source):
            return .restore(proposed: .normalized(source, policy: policy))
        }
    }
}
