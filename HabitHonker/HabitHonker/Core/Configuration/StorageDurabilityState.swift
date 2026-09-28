//
//  StorageDurabilityState.swift
//  HabitHonker
//

import Foundation

/// Which storage world the app's current SwiftData container belongs to.
///
/// Decided once, by the composition root that built the container (`PersistentStoreFactory`,
/// called from `HabitHonkerApp`), and passed down through `AppDependencies`. Repositories and
/// services never rediscover it by inspecting CloudKit settings.
enum StorageDurabilityState: String, Equatable, Sendable, CaseIterable {
    /// Persistent store mirrored to the user's private CloudKit database (sync on and iCloud
    /// available). Multi-device semantics are provisional/convergent; no global exactly-once promise.
    case durableCloud
    /// Persistent on-device store with CloudKit explicitly disabled. A first-class storage world:
    /// survives restarts and needs no network or iCloud account.
    case durableLocal
    /// Temporary in-memory store used only when no persistent store could be opened.
    /// Everything in it is lost when the app quits.
    case ephemeralFallback

    /// Whether durable gamification may run on this storage: profile enrollment, persistent
    /// XP/coins, gamified completion and reconciliation writes. Ephemeral storage must never
    /// look like durable progress.
    var supportsDurableGamification: Bool {
        switch self {
        case .durableCloud, .durableLocal:
            return true
        case .ephemeralFallback:
            return false
        }
    }
}
