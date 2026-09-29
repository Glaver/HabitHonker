//
//  HabitMutationResult.swift
//  HabitHonker
//

import Foundation

/// A committed Habit create/metadata/priority mutation and its schedule-history effect (Phase 4B).
///
/// Returned by the repository actor for tests and diagnostics. The repository protocol and the
/// service keep returning `habit` only; `scheduleHistory` is never persisted.
struct HabitMutationResult {
    /// The fresh persisted Habit, with its current completion history.
    let habit: HabitModel
    let scheduleHistory: ScheduleHistoryOutcome
}
