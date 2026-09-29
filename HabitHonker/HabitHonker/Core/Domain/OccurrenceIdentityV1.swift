//
//  OccurrenceIdentityV1.swift
//  HabitHonker
//

import Foundation

/// V1 logical occurrence identity. The format is frozen: changing it would mint new identities
/// for existing occurrences and re-open their reward entitlements.
struct OccurrenceIdentityV1: OccurrenceIdentifying {
    init() {}

    func repeatingOccurrenceID(targetID: BehaviorTargetID, localDay: LocalDay) -> String {
        "occ:v1:\(BehaviorLogicalIdentity.canonicalUUIDText(targetID.rawValue)):day:\(localDay.canonicalKey)"
    }

    func oneTimeOccurrenceID(targetID: BehaviorTargetID) -> String {
        "occ:v1:\(BehaviorLogicalIdentity.canonicalUUIDText(targetID.rawValue)):once"
    }
}
