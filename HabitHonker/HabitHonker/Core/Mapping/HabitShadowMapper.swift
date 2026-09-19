//
//  HabitShadowMapper.swift
//  HabitHonker
//

import Foundation

enum HabitShadowMapper {
    static func behaviorTarget(from habit: HabitModel) -> BehaviorTarget {
        BehaviorTarget(
            id: BehaviorTargetID(habit.id),
            iconName: habit.icon,
            title: habit.title,
            description: habit.description,
            tags: habit.tags,
            priority: behaviorPriority(from: habit.priority),
            schedule: behaviorSchedule(from: habit),
            reminderConfig: reminderConfig(from: habit)
        )
    }

    static func behaviorPriority(from priority: PriorityEisenhower) -> BehaviorPriority {
        switch priority {
        case .importantAndUrgent:
            return .importantAndUrgent
        case .urgentButNotImportant:
            return .urgentButNotImportant
        case .importantButNotUrgent:
            return .importantButNotUrgent
        case .notUrgentAndNotImportant:
            return .notUrgentAndNotImportant
        }
    }

    static func behaviorSchedule(from habit: HabitModel) -> BehaviorSchedule {
        switch habit.type {
        case .repeating:
            return .repeating(weekdays: Set(habit.repeating.map(\.behaviorWeekday)))
        case .dueDate:
            return .oneTime(dueDate: habit.dueDate)
        }
    }

    static func reminderConfig(from habit: HabitModel) -> TargetReminderConfig {
        guard habit.isNotificationActivated else {
            return TargetReminderConfig(isEnabled: false, deliveryTime: nil)
        }

        return TargetReminderConfig(isEnabled: true, deliveryTime: habit.dueDate)
    }

    static func completionEvent(
        from record: HabitModel.HabitRecord,
        targetID: BehaviorTargetID
    ) -> BehaviorEvent {
        BehaviorEvent(
            id: record.id,
            targetID: targetID,
            occurredAt: record.date,
            kind: .completed(count: record.count)
        )
    }

    static func completionEvents(from habit: HabitModel) -> [BehaviorEvent] {
        let targetID = BehaviorTargetID(habit.id)
        return habit.record.map { completionEvent(from: $0, targetID: targetID) }
    }

    static func archivedEvent(
        from deletedHabit: DeletedHabitSD,
        eventID: UUID = UUID()
    ) -> BehaviorEvent {
        BehaviorEvent(
            id: eventID,
            targetID: BehaviorTargetID(deletedHabit.id),
            occurredAt: deletedHabit.deletedAt,
            kind: .archived
        )
    }
}

private extension Weekday {
    var behaviorWeekday: BehaviorWeekday {
        guard let weekday = BehaviorWeekday(rawValue: rawValue) else {
            preconditionFailure("Weekday and BehaviorWeekday raw values must stay aligned.")
        }

        return weekday
    }
}
