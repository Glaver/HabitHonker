protocol BehaviorTransactionRepositoryProtocol: Sendable {
    func complete(_ command: BehaviorCompletionCommand) async throws -> BehaviorTransactionResult
}
