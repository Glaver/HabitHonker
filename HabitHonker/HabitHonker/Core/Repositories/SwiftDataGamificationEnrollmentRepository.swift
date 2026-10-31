/// Shares the existing persistence actor (Phase 4E). It never creates a container or another actor,
/// so enrollment is serialized with every other write to the same store.
struct SwiftDataGamificationEnrollmentRepository: GamificationEnrollmentRepositoryProtocol {
    private let repository: HabitsRepositorySwiftData

    init(repository: HabitsRepositorySwiftData) {
        self.repository = repository
    }

    func enroll(_ request: GamificationEnrollmentRequest) async throws -> GamificationEnrollmentResult {
        try await repository.enrollGamification(request)
    }
}
