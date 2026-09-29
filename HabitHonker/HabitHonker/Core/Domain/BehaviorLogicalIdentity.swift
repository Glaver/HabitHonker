//
//  BehaviorLogicalIdentity.swift
//  HabitHonker
//

import Foundation

/// Canonical V1 logical keys that are not occurrence keys, and the V1 UUID text encoding.
///
/// Logical keys are business identities, identical on every device and after every restart.
/// They are frozen: changing a format would mint new identities for existing data.
enum BehaviorLogicalIdentity {
    /// The one canonical V1 logical profile key (one logical profile per durable store).
    static let defaultProfileKey = "profile:v1:default"

    /// V1 UUID text inside logical keys: the standard 8-4-4-4-12 form, lowercase.
    static func canonicalUUIDText(_ uuid: UUID) -> String {
        uuid.uuidString.lowercased()
    }

    /// Deterministic enrollment-baseline revision key: `rev:v1:<target uuid>:baseline`.
    /// Two devices that enroll the same target independently produce the same key.
    static func baselineRevisionID(targetID: BehaviorTargetID) -> String {
        "rev:v1:\(canonicalUUIDText(targetID.rawValue)):baseline"
    }
}
