struct BehaviorTransactionService: BehaviorTransactionServiceProtocol {
    private let repository: any BehaviorTransactionRepositoryProtocol

    init(repository: any BehaviorTransactionRepositoryProtocol) {
        self.repository = repository
    }

    func complete(_ command: BehaviorCompletionCommand) async throws -> BehaviorTransactionResult {
        try await repository.complete(command)
    }
}
