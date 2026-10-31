import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4E E65–E69, E85: the profile and every baseline are staged in one context of the one
/// repository actor and saved once, or not at all. After any failure the store equals its
/// pre-enrollment state in every field of every table.
@MainActor
final class GamificationEnrollmentAtomicityTests: XCTestCase {

    // MARK: E65 — injected failure after the whole write set is staged

    func testE65InjectedFailureAfterStagingLeavesNoProfileAndNoBaseline() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let at = Enroll.at
        let expectedBaselines = Enroll.representative.count
        await repository.setBeforeCommitForTesting { context in
            // Everything is staged in this one context...
            let profiles = try context.fetch(FetchDescriptor<GamificationProfileSD>())
            XCTAssertEqual(profiles.map(\.trackingStartedAt), [at])
            let revisions = try context.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>())
            XCTAssertEqual(revisions.count, expectedBaselines)
            XCTAssertTrue(revisions.allSatisfy { $0.logicalRevisionID.hasSuffix(":baseline") && $0.effectiveFrom == at })
            // ...and nothing has been saved yet.
            let persisted = ModelContext(context.container)
            XCTAssertEqual(try persisted.fetchCount(FetchDescriptor<GamificationProfileSD>()), 0)
            XCTAssertEqual(try persisted.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 0)
            throw Sched.injected
        }
        do {
            _ = try await Enroll.service(repository).enroll(Enroll.request())
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before)
        XCTAssertEqual(try Enroll.profiles(store), [])
        XCTAssertEqual(try Enroll.allRows(store), [])

        // Nothing was left behind: the same enrollment succeeds once the failure is gone.
        await repository.setBeforeCommitForTesting(nil)
        let retry = try await Enroll.service(repository).enroll(Enroll.request())
        XCTAssertEqual(retry, .enrolled(Enroll.summary(baselines: expectedBaselines)))
    }

    // MARK: E66 — a real failing save

    func testE66RealFailingSaveLeavesNoPartialEnrollment() async throws {
        try await withReadOnlyStore(seed: { try Enroll.seedRepresentative($0) }) { store in
            XCTAssertEqual(try Enroll.profiles(store), [])
            XCTAssertEqual(try Enroll.allRows(store), [])
        }
    }

    // MARK: E67 — failure while deriving the baselines

    func testE67FailureWhileDerivingABaselineLeavesNothing() async throws {
        let store = try TxStore.memory()
        _ = try Enroll.seedHabits(store, count: 4)
        // A second physical row for one target (a sync anomaly): no single baseline can describe it.
        let duplicated = Enroll.uuid(102)
        try Sched.seedHabit(store, Sched.HabitSeed(id: duplicated, title: "Duplicate", priority: .importantAndUrgent))
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let commits = CallCounter()
        await repository.setBeforeCommitForTesting { _ in commits.increment() }

        try await Enroll.assertRefused(.requiresReconciliation(.duplicateActiveHabit(BehaviorTargetID(duplicated))), store: store) {
            try await Enroll.service(repository).enroll(Enroll.request())
        }
        XCTAssertEqual(commits.count, 0, "the save is never reached")
        XCTAssertEqual(try Enroll.profiles(store), [], "no profile without every baseline")
        XCTAssertEqual(try Enroll.allRows(store), [], "no partial baseline set")
    }

    // MARK: E68 — initializing an existing unenrolled profile rolls back too

    func testE68FailedInitializationKeepsTheExistingProfileUnenrolled() async throws {
        let store = try TxStore.memory()
        try Sched.seedProfile(store, trackingStartedAt: nil, timeZone: nil, calendar: nil)
        let physicalID = try Enroll.onlyProfile(store).physicalID
        try Enroll.seedRepresentative(store)
        let before = try TxStore.state(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let at = Enroll.at
        await repository.setBeforeCommitForTesting { context in
            let staged = try context.fetch(FetchDescriptor<GamificationProfileSD>())
            XCTAssertEqual(staged.map(\.id), [physicalID], "initialized in place")
            XCTAssertEqual(staged.map(\.trackingStartedAt), [at])
            throw Sched.injected
        }
        do {
            _ = try await Enroll.service(repository).enroll(Enroll.request())
            XCTFail("expected the injected failure")
        } catch {
            Sched.assertInjected(error)
        }
        XCTAssertEqual(try TxStore.state(store), before)
        let profile = try Enroll.onlyProfile(store)
        XCTAssertEqual(profile.physicalID, physicalID)
        XCTAssertNil(profile.trackingStartedAt)
        XCTAssertNil(profile.schedulingTimeZoneIdentifier)
        XCTAssertNil(profile.schedulingCalendarIdentifier)
        XCTAssertEqual(try Enroll.allRows(store), [])
    }

    func testE68RealFailingSaveKeepsTheExistingProfileUnenrolled() async throws {
        try await withReadOnlyStore(seed: { store in
            try Sched.seedProfile(store, trackingStartedAt: nil, timeZone: nil, calendar: nil)
            try Enroll.seedRepresentative(store)
        }) { store in
            XCTAssertNil(try Enroll.onlyProfile(store).trackingStartedAt)
            XCTAssertEqual(try Enroll.allRows(store), [])
        }
    }

    // MARK: E69 — one context, one save

    func testE69ProfileAndEveryBaselineAreStagedInOneContextAndSavedOnce() async throws {
        let store = try TxStore.memory()
        _ = try Enroll.seedHabits(store, count: 12)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        let commits = CallCounter()
        await repository.setBeforeCommitForTesting { context in
            commits.increment()
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<GamificationProfileSD>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 12)
            let persisted = ModelContext(context.container)
            XCTAssertEqual(try persisted.fetchCount(FetchDescriptor<GamificationProfileSD>()), 0, "no earlier save")
            XCTAssertEqual(try persisted.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 0, "no earlier save")
        }
        let result = try await Enroll.service(repository).enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 12)))
        XCTAssertEqual(commits.count, 1, "exactly one commit")
        XCTAssertEqual(try Enroll.profiles(store).count, 1)
        XCTAssertEqual(try Enroll.allRows(store).count, 12)

        // A repeat enrollment and a refusal never reach the save.
        _ = try await Enroll.service(repository).enroll(Enroll.request())
        _ = try? await Enroll.service(repository).enroll(Enroll.request(zone: "Asia/Tokyo"))
        XCTAssertEqual(commits.count, 1)
    }

    // MARK: E85 — concurrent calls on the one actor enroll once (local serialization only)

    func testE85ConcurrentEnrollmentCallsOnOneActorEnrollExactlyOnce() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        let service = Enroll.service(Sched.repository(store, ids: Sched.UUIDSequence()))
        let requests = (0..<12).map { Enroll.request(at: Sched.at(day: 0, hour: 9, minute: $0)) }
        let results = try await withThrowingTaskGroup(of: GamificationEnrollmentResult.self) { group in
            for request in requests {
                group.addTask { try await service.enroll(request) }
            }
            var collected: [GamificationEnrollmentResult] = []
            for try await result in group { collected.append(result) }
            return collected
        }
        XCTAssertEqual(results.count, 12)
        let enrolled = results.compactMap { result -> GamificationEnrollmentSummary? in
            if case let .enrolled(summary) = result { return summary }
            return nil
        }
        XCTAssertEqual(enrolled.count, 1, "exactly one call enrolls")
        let winner = try XCTUnwrap(enrolled.first)
        XCTAssertEqual(results.filter { $0 == .alreadyEnrolled(winner) }.count, 11, "every other call observes that enrollment")
        let profile = try Enroll.onlyProfile(store)
        XCTAssertEqual(profile.trackingStartedAt, winner.trackingStartedAt)
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, Enroll.representative.count, "no duplicate local baseline")
        XCTAssertEqual(Set(rows.map(\.logicalRevisionID)).count, Enroll.representative.count)
        XCTAssertEqual(Set(rows.map(\.effectiveFrom)), [winner.trackingStartedAt])
    }

    // MARK: - Helpers

    /// Seeds an on-disk store, reopens it read-only, and expects enrollment to fail in the real save
    /// with the store left exactly as it was.
    private func withReadOnlyStore(seed: (ModelContainer) throws -> Void,
                                   file: StaticString = #filePath, line: UInt = #line,
                                   then check: (ModelContainer) throws -> Void) async throws {
        let directory = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("read-only.store")
        try autoreleasepool {
            try seed(try TxStore.disk(url))
        }
        let store = try TxStore.disk(url, allowsSave: false)
        let before = try TxStore.state(store)
        do {
            let result = try await Enroll.service(store).enroll(Enroll.request())
            XCTFail("a read-only store's save must fail, got \(result)", file: file, line: line)
        } catch {
            XCTAssertNil(error as? GamificationEnrollmentError, "expected the persistence error, got \(error)", file: file, line: line)
            XCTAssertFalse(error is Sched.InjectedFailure, file: file, line: line)
        }
        XCTAssertEqual(try TxStore.state(store), before, "no partial enrollment may persist", file: file, line: line)
        try check(store)
    }
}

/// Thread-safe call counter for the before-commit seam, which runs on the repository actor.
final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock(); value += 1; lock.unlock()
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}
