/// Shares the existing persistence actor; it never creates a container or another actor.
struct SwiftDataBehaviorTransactionRepository: BehaviorTransactionRepositoryProtocol {
    private let repository: HabitsRepositorySwiftData
    private let transaction: BehaviorTransactionSD

    init(repository: HabitsRepositorySwiftData, gamificationService: any GamificationServiceProtocol) {
        self.repository = repository
        self.transaction = BehaviorTransactionSD(gamificationService: gamificationService)
    }

    func complete(_ command: BehaviorCompletionCommand) async throws -> BehaviorTransactionResult {
        try await repository.completeBehavior(command, transaction: transaction)
    }
}
