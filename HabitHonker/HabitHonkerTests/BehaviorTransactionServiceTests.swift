import XCTest
@testable import HabitHonker

final class BehaviorTransactionServiceTests: XCTestCase {
    func testExactDelegationAndIndependentServices() async throws {
        let command = TxCommand.make()
        let sentinel = BehaviorTransactionResult.duplicateCommand(BehaviorCommandReceipt(commandID: "sentinel",
            transitionID: "s", targetID: command.targetID, occurrenceID: "s", completedAt: command.completedAt, completionCount: 19))
        let first = TransactionRepositorySpy(result: sentinel)
        let second = TransactionRepositorySpy(result: sentinel)
        let a = BehaviorTransactionService(repository: first)
        let b = BehaviorTransactionService(repository: second)
        let result = try await a.complete(command)
        XCTAssertEqual(result, sentinel)
        let calls = await first.commands
        let untouched = await second.commands
        XCTAssertEqual(calls, [command]); XCTAssertTrue(untouched.isEmpty)
        _ = try await b.complete(command)
        let secondCalls = await second.commands
        XCTAssertEqual(secondCalls, [command])
    }

    func testRepositoryErrorPropagates() async {
        let service = BehaviorTransactionService(repository: TransactionRepositorySpy(result: nil))
        do { _ = try await service.complete(TxCommand.make()); XCTFail("Expected error") }
        catch { XCTAssertEqual(error as? BehaviorTransactionError, .profileNotFound("test")) }
    }
}

private actor TransactionRepositorySpy: BehaviorTransactionRepositoryProtocol {
    var commands: [BehaviorCompletionCommand] = []
    let result: BehaviorTransactionResult?
    init(result: BehaviorTransactionResult?) { self.result = result }
    func complete(_ command: BehaviorCompletionCommand) async throws -> BehaviorTransactionResult {
        commands.append(command)
        guard let result else { throw BehaviorTransactionError.profileNotFound("test") }
        return result
    }
}
