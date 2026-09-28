//
//  HabitMetadata.swift
//  HabitHonker
//

import SwiftUI

/// Every user-editable Habit field except completion history.
///
/// Metadata writes (Details save, Priority Matrix) carry this value instead of a whole
/// `HabitModel`, so a stale draft can never replace, drop or duplicate completion records.
/// Completion history changes only through `recordLegacyCompletion`.
struct HabitMetadata: Equatable {
    var icon: String?
    var iconColor: Color
    var title: String
    var description: String
    var tags: [String]
    var priority: PriorityEisenhower
    var type: HabitType
    var repeating: Set<Weekday>
    var dueDate: Date
    var isNotificationActivated: Bool
}

extension HabitMetadata {
    /// Copies the editable fields and deliberately ignores `habit.record`.
    init(_ habit: HabitModel) {
        self.init(icon: habit.icon,
                  iconColor: habit.iconColor,
                  title: habit.title,
                  description: habit.description,
                  tags: habit.tags,
                  priority: habit.priority,
                  type: habit.type,
                  repeating: habit.repeating,
                  dueDate: habit.dueDate,
                  isNotificationActivated: habit.isNotificationActivated)
    }
}

/// Typed outcomes of the explicit Habit create/update/completion operations.
enum HabitRepositoryError: Error, Equatable {
    /// Create was asked for an ID that already has an active row. Nothing was overwritten.
    case alreadyExists(UUID)
    /// Update/completion was asked for an ID without an active row. Nothing was inserted.
    case notFound(UUID)
    /// Incrementing a legacy day record would overflow `Int`. Nothing was written.
    case completionCountOverflow(UUID)
}
