//
//  OccurrenceIdentifying.swift
//  HabitHonker
//

import Foundation

/// Deterministic logical occurrence identity (V1).
///
/// Inputs are deliberately minimal: a repeating occurrence is its target plus its civil day, and a
/// one-time occurrence is its target alone. Invariants, tested in `OccurrenceIdentityTests`:
/// - I1-I3: the same target on the same civil date always gives the same key; another date or
///   another target gives another key.
/// - I4: a one-time key has no due-date input, so due-date edits never mint a new key.
/// - I5-I8: keys are identical across instances, launches, devices and locales. The civil date comes
///   from a `LocalDay` computed in the explicit scheduling time zone, never the device's.
/// - I9: daylight saving changes a day's length, never its key.
/// - I10: physical row ids are never part of a key.
protocol OccurrenceIdentifying: Sendable {
    /// `occ:v1:<target uuid>:day:<YYYY-MM-DD>`
    func repeatingOccurrenceID(targetID: BehaviorTargetID, localDay: LocalDay) -> String

    /// `occ:v1:<target uuid>:once`: one lifetime occurrence per target.
    func oneTimeOccurrenceID(targetID: BehaviorTargetID) -> String
}
