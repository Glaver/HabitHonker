//
//  GamificationEnrollmentService.swift
//  HabitHonker
//

import Foundation

/// Explicit enrollment for the store this dependency graph is scoped to (Phase 4E).
///
/// The service owns the durability gate and request validation. The atomic write belongs to the
/// repository. It calculates no reward, plans no occurrence and reconciles nothing.
struct GamificationEnrollmentService: GamificationEnrollmentServicing {
    private let repository: any GamificationEnrollmentRepositoryProtocol
    /// Decided by the composition root that opened the store. It is never rediscovered here.
    private let storageDurability: StorageDurabilityState

    init(repository: any GamificationEnrollmentRepositoryProtocol, storageDurability: StorageDurabilityState) {
        self.repository = repository
        self.storageDurability = storageDurability
    }

    func enroll(_ request: GamificationEnrollmentRequest) async throws -> GamificationEnrollmentResult {
        // Ephemeral storage never enrolls, so it cannot look like durable progress. Nothing reaches the store.
        guard storageDurability.supportsDurableGamification else {
            throw GamificationEnrollmentError.storageNotDurable(storageDurability)
        }
        // Refuse an invalid policy before touching persistence. The repository validates again.
        _ = try request.schedulingPolicy()
        return try await repository.enroll(request)
    }
}
