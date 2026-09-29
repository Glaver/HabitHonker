//
//  BehaviorScheduleRevisionMapper.swift
//  HabitHonker
//

import Foundation
import SwiftData

/// Maps persisted rows to and from the pure schedule-history values (Phase 4B).
enum BehaviorScheduleRevisionMapper {
    /// The revision-relevant facts of a current Habit row, interpreted exactly as the app interprets
    /// the row today (`HabitMapper.toDomain`): an unknown type reads as repeating, an unknown priority
    /// as Important / Urgent, and weekday values outside 1...7 are ignored.
    static func source(from habit: HabitSD) -> BehaviorScheduleSource {
        let type = HabitType(rawValue: habit.typeRaw) ?? .repeating
        let priority = PriorityEisenhower(rawValue: habit.priorityRaw) ?? .importantAndUrgent
        return BehaviorScheduleSource(
            targetID: BehaviorTargetID(habit.id),
            taskType: type == .repeating ? .repeating : .oneTime,
            weekdays: Set(habit.repeatingWeekdays.compactMap(BehaviorWeekday.init(rawValue:))),
            dueDate: habit.dueDate,
            notificationEnabled: habit.notificationActivated,
            priority: HabitShadowMapper.behaviorPriority(from: priority),
            iconName: habit.icon
        )
    }

    static func profileFacts(from profile: GamificationProfileSD) -> BehaviorScheduleProfileFacts {
        BehaviorScheduleProfileFacts(trackingStartedAt: profile.trackingStartedAt,
                                     schedulingTimeZoneIdentifier: profile.schedulingTimeZoneIdentifier,
                                     schedulingCalendarIdentifier: profile.schedulingCalendarIdentifier)
    }

    static func facts(from row: BehaviorScheduleRevisionSD) -> BehaviorScheduleRevisionFacts {
        BehaviorScheduleRevisionFacts(logicalRevisionID: row.logicalRevisionID,
                                      effectiveFrom: row.effectiveFrom,
                                      effectiveTo: row.effectiveTo,
                                      snapshot: snapshot(from: row))
    }

    /// The stored planning payload, or nil when it is not a complete V1 payload (unknown row schema
    /// version, task type or priority; missing notification state, time zone or calendar).
    /// Values are taken as stored, never repaired; a stored payload that breaks the normalization
    /// rules still decodes and then compares unequal to every normalized snapshot.
    static func snapshot(from row: BehaviorScheduleRevisionSD) -> BehaviorScheduleSnapshot? {
        guard row.schemaVersion == 1,
              let taskType = GamificationTaskType(rawValue: row.taskTypeRawValue),
              let priorityRawValue = row.priorityRawValue,
              let priority = BehaviorPriority(rawValue: priorityRawValue),
              let notificationEnabled = row.notificationEnabled,
              let timeZoneIdentifier = row.schedulingTimeZoneIdentifier,
              let calendarIdentifier = row.schedulingCalendarIdentifier else {
            return nil
        }
        return BehaviorScheduleSnapshot(targetID: BehaviorTargetID(row.targetID),
                                        taskType: taskType,
                                        selectedWeekdaysMask: row.selectedWeekdaysMask,
                                        scheduledHour: row.scheduledHour,
                                        scheduledMinute: row.scheduledMinute,
                                        dueAt: row.dueAt,
                                        schedulingTimeZoneIdentifier: timeZoneIdentifier,
                                        schedulingCalendarIdentifier: calendarIdentifier,
                                        priority: priority,
                                        iconName: row.iconName,
                                        notificationEnabled: notificationEnabled)
    }

    /// A new open revision row (payload version 1). The physical row id is SwiftData's own and is
    /// never used as the logical identity.
    static func makeOpenRow(logicalRevisionID: String,
                            effectiveFrom: Date,
                            snapshot: BehaviorScheduleSnapshot) -> BehaviorScheduleRevisionSD {
        BehaviorScheduleRevisionSD(logicalRevisionID: logicalRevisionID,
                                   targetID: snapshot.targetID.rawValue,
                                   effectiveFrom: effectiveFrom,
                                   effectiveTo: nil,
                                   taskTypeRawValue: snapshot.taskType.rawValue,
                                   selectedWeekdaysMask: snapshot.selectedWeekdaysMask,
                                   scheduledHour: snapshot.scheduledHour,
                                   scheduledMinute: snapshot.scheduledMinute,
                                   dueAt: snapshot.dueAt,
                                   schedulingTimeZoneIdentifier: snapshot.schedulingTimeZoneIdentifier,
                                   schedulingCalendarIdentifier: snapshot.schedulingCalendarIdentifier,
                                   priorityRawValue: snapshot.priority.rawValue,
                                   iconName: snapshot.iconName,
                                   notificationEnabled: snapshot.notificationEnabled,
                                   schemaVersion: 1)
    }
}
