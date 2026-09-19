import XCTest
@testable import HabitHonker

@MainActor
final class HabitMutationCoordinatorTests: XCTestCase {
    func testSameUUIDRunsFIFOWithoutOverlapAndSlotCanBeReused() async {
        let coordinator = HabitMutationCoordinator()
        let id = UUID()
        let gate = MutationTestGate()
        var order: [String] = []
        let first = Task {
            await coordinator.withMutation(for: id) {
                order.append("first start")
                await gate.pause()
                order.append("first end")
            }
        }
        await fulfillment(of: [gate.entered], timeout: 5)
        let secondRequested = expectation(description: "Second submitted")
        let second = Task {
            secondRequested.fulfill()
            await coordinator.withMutation(for: id) { order.append("second") }
        }
        await fulfillment(of: [secondRequested], timeout: 5)
        let thirdRequested = expectation(description: "Third submitted")
        let third = Task {
            thirdRequested.fulfill()
            await coordinator.withMutation(for: id) { order.append("third") }
        }
        await fulfillment(of: [thirdRequested], timeout: 5)
        XCTAssertEqual(order, ["first start"])
        gate.open()
        await first.value
        await second.value
        await third.value
        await coordinator.withMutation(for: id) { order.append("reused") }
        XCTAssertEqual(order, ["first start", "first end", "second", "third", "reused"])
    }

    func testDifferentUUIDProceedsWhileFirstIsSuspended() async {
        let coordinator = HabitMutationCoordinator()
        let gate = MutationTestGate()
        let first = Task {
            await coordinator.withMutation(for: UUID()) { await gate.pause() }
        }
        await fulfillment(of: [gate.entered], timeout: 5)
        let finished = expectation(description: "Independent operation finished")
        let other = Task {
            await coordinator.withMutation(for: UUID()) { finished.fulfill() }
        }
        await fulfillment(of: [finished], timeout: 5)
        gate.open()
        await first.value
        await other.value
    }

    func testThrowReleasesSlotAndQueuedOperationStillRuns() async {
        let coordinator = HabitMutationCoordinator()
        let id = UUID()
        let gate = MutationTestGate()
        var order: [String] = []
        let first = Task {
            do {
                try await coordinator.withMutation(for: id) {
                    await gate.pause()
                    order.append("throw")
                    throw TestFailure.expected
                }
                XCTFail("Expected operation failure")
            } catch {
                XCTAssertTrue(error is TestFailure)
            }
        }
        await fulfillment(of: [gate.entered], timeout: 5)
        let requested = expectation(description: "Successor submitted")
        let successor = Task {
            requested.fulfill()
            await coordinator.withMutation(for: id) { order.append("successor") }
        }
        await fulfillment(of: [requested], timeout: 5)
        XCTAssertTrue(order.isEmpty)
        gate.open()
        await first.value
        await successor.value
        await coordinator.withMutation(for: id) { order.append("reused") }
        XCTAssertEqual(order, ["throw", "successor", "reused"])
    }
}

private enum TestFailure: Error { case expected }

@MainActor
private final class MutationTestGate {
    let entered = XCTestExpectation(description: "Operation suspended")
    private var continuation: CheckedContinuation<Void, Never>?

    func pause() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            entered.fulfill()
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
