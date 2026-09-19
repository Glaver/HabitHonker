import Foundation

/// Serializes full mutations in arrival order for each habit, including awaits.
/// Different UUIDs have independent slots. Queued work is retained even if its
/// caller is cancelled; the operation still runs and releases its slot on exit.
@MainActor
final class HabitMutationCoordinator {
    private var waiters: [UUID: [CheckedContinuation<Void, Never>]] = [:]

    func withMutation(for id: UUID, operation: @MainActor () async throws -> Void) async rethrows {
        await acquire(id)
        defer { release(id) }
        try await operation()
    }

    private func acquire(_ id: UUID) async {
        if waiters[id] == nil {
            waiters[id] = []
            return
        }
        await withCheckedContinuation { continuation in
            waiters[id, default: []].append(continuation)
        }
    }

    private func release(_ id: UUID) {
        guard var queued = waiters[id], !queued.isEmpty else {
            waiters.removeValue(forKey: id)
            return
        }
        let next = queued.removeFirst()
        // Keep the slot owned during handoff so new arrivals cannot overtake it.
        waiters[id] = queued
        next.resume()
    }
}
