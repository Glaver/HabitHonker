import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4B B26-B31: the frozen V1 normal revision identity, and that IDs are minted only for
/// revisions that are actually inserted.
@MainActor
final class BehaviorScheduleRevisionIdentityTests: XCTestCase {
    private static let exampleRevision = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let mixedCaseTarget = BehaviorTargetID(UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!)

    // MARK: B26-B29 - format

    func testB26NormalRevisionIDFormatIsExact() {
        XCTAssertEqual(BehaviorScheduleRevisionIDProviderV1.changeRevisionID(targetID: Sched.target,
                                                                              revisionUUID: Self.exampleRevision),
                       "rev:v1:123e4567-e89b-12d3-a456-426614174000:change:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
    }

    func testB27TargetUUIDIsLowercaseCanonicalText() {
        let id = BehaviorScheduleRevisionIDProviderV1.changeRevisionID(targetID: Self.mixedCaseTarget,
                                                                        revisionUUID: Self.exampleRevision)
        XCTAssertEqual(id, "rev:v1:a0b1c2d3-e4f5-4678-9abc-def012345678:change:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        XCTAssertEqual(id, id.lowercased())
    }

    func testB28RevisionUUIDIsLowercaseCanonicalText() {
        let mixed = UUID(uuidString: "0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0")!
        let id = BehaviorScheduleRevisionIDProviderV1.changeRevisionID(targetID: Sched.target, revisionUUID: mixed)
        XCTAssertTrue(id.hasSuffix(":change:0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0"), id)
        XCTAssertFalse(id.contains(mixed.uuidString), "uppercase Foundation text must not leak into the key")
        XCTAssertEqual(id.components(separatedBy: ":").count, 5)
    }

    func testB29FixedProviderIsDeterministic() {
        let fixed = Self.exampleRevision
        let first = BehaviorScheduleRevisionIDProviderV1(uuid: { fixed })
        let second = BehaviorScheduleRevisionIDProviderV1(uuid: { fixed })
        let expected = "rev:v1:123e4567-e89b-12d3-a456-426614174000:change:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        for _ in 0..<3 {
            XCTAssertEqual(first.makeRevisionID(targetID: Sched.target), expected)
            XCTAssertEqual(second.makeRevisionID(targetID: Sched.target), expected)
        }
        // The baseline key of the same target is a different, frozen 4C format.
        XCTAssertEqual(BehaviorLogicalIdentity.baselineRevisionID(targetID: Sched.target),
                       "rev:v1:123e4567-e89b-12d3-a456-426614174000:baseline")
        XCTAssertNotEqual(first.makeRevisionID(targetID: Sched.target),
                          BehaviorLogicalIdentity.baselineRevisionID(targetID: Sched.target))
    }

    func testProductionProviderMintsAFreshCanonicalRevisionUUIDEachTime() throws {
        let provider = BehaviorScheduleRevisionIDProviderV1()
        let prefix = "rev:v1:123e4567-e89b-12d3-a456-426614174000:change:"
        let first = provider.makeRevisionID(targetID: Sched.target)
        let second = provider.makeRevisionID(targetID: Sched.target)
        XCTAssertNotEqual(first, second)
        for id in [first, second] {
            XCTAssertTrue(id.hasPrefix(prefix), id)
            let suffix = String(id.dropFirst(prefix.count))
            let uuid = try XCTUnwrap(UUID(uuidString: suffix), id)
            XCTAssertEqual(suffix, uuid.uuidString.lowercased())
        }
    }

    // MARK: B30-B31 - no revision, no ID

    func testB30NoOpAndNotEnrolledMutationsMintNoRevisionID() async throws {
        let store = try Sched.enrolledStore()
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(store, ids: ids)
        let at = Sched.at(day: 1, hour: 10)

        let titleOnly = try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata { $0.title = "Gym (late)" },
                                                            effectiveAt: at)
        let identical = try await repository.updateMetadata(id: Sched.targetUUID, metadata: Sched.metadata(), effectiveAt: at)
        let samePriority = try await repository.updatePriority(id: Sched.targetUUID, priority: .importantButNotUrgent, effectiveAt: at)
        XCTAssertEqual(titleOnly.scheduleHistory, .revisionNotRequired)
        XCTAssertEqual(identical.scheduleHistory, .revisionNotRequired)
        XCTAssertEqual(samePriority.scheduleHistory, .revisionNotRequired)

        let unenrolled = try TxStore.memory()
        let unenrolledRepository = Sched.repository(unenrolled, ids: ids)
        let created = try await unenrolledRepository.createHabit(id: Sched.otherUUID, metadata: Sched.metadata(), effectiveAt: at)
        XCTAssertEqual(created.scheduleHistory, .notEnrolled)

        XCTAssertEqual(ids.count, 0)
        XCTAssertEqual(try Sched.rows(store).count, 1)
    }

    func testB31DeferredMutationsMintNoRevisionID() async throws {
        let store = try Sched.enrolledStore()
        try Sched.seedRevision(store, Sched.RevisionSeed(logicalID: Sched.changeID(9))) // a second open revision
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(store, ids: ids)
        let at = Sched.at(day: 1, hour: 10)

        let priority = try await repository.updatePriority(id: Sched.targetUUID, priority: .urgentButNotImportant, effectiveAt: at)
        let schedule = try await repository.updateMetadata(id: Sched.targetUUID,
                                                           metadata: Sched.metadata { $0.repeating = [.tuesday] }, effectiveAt: at)
        let deleted = try await repository.delete(id: Sched.targetUUID, effectiveAt: at)
        let restored = try await repository.restoreDeletedHabit(id: Sched.targetUUID, effectiveAt: Sched.at(day: 2, hour: 10))

        for outcome in [priority.scheduleHistory, schedule.scheduleHistory, deleted, restored] {
            XCTAssertEqual(outcome, .revisionDeferred(.multipleOpenRevisions(count: 2)))
        }
        XCTAssertEqual(ids.count, 0)
    }
}
