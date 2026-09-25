import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

@MainActor
final class BehaviorTransactionAtomicityTests: XCTestCase {
    func testMissingProfileCommitsNothingEvenForIneligibleCompletion() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store, profile: false)
        try await TxStore.assertFailure(store, error: .profileNotFound("profile:v1:default"))
        try await TxStore.assertFailure(store, command: TxCommand.make(eligibility: .ineligible), error: .profileNotFound("profile:v1:default"))
    }
    func testMissingTargetCommitsNothing() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store, habit: false)
        try await TxStore.assertFailure(store, error: .targetNotFound(TxCommand.target))
    }
    func testDuplicateProfileCommitsNothing() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let ctx = ModelContext(store); ctx.insert(GamificationProfileSD(logicalProfileKey: "profile:v1:default")); try ctx.save()
        try await TxStore.assertFailure(store, error: .duplicateProfileKey("profile:v1:default"))
    }
    func testDuplicateTargetCommitsNothing() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let ctx = ModelContext(store); ctx.insert(HabitSD(id: TxCommand.target.rawValue)); try ctx.save()
        try await TxStore.assertFailure(store, error: .duplicateTarget(TxCommand.target))
    }
    func testDuplicateOccurrenceCommitsNothing() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let ctx = ModelContext(store)
        for _ in 0..<2 {
            ctx.insert(TaskOccurrenceSD(logicalOccurrenceID: TxCommand.make().occurrenceID, targetID: TxCommand.target.rawValue,
                taskTypeRawValue: "repeating", statusRawValue: "scheduled", provenanceRawValue: "native:v1"))
        }
        try ctx.save()
        try await TxStore.assertFailure(store, error: .duplicateOccurrenceKey(TxCommand.make().occurrenceID))
    }
    func testDuplicateLedgerCommitsNothing() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        _ = try await TxStore.service(store).complete(TxCommand.make())
        let ctx = ModelContext(store)
        ctx.insert(GamificationLedgerEntrySD(logicalKey: TxCommand.make().initialRewardKey, profileKey: "profile:v1:default",
            targetID: TxCommand.target.rawValue, occurrenceID: TxCommand.make().occurrenceID, reasonRawValue: "completion",
            createdAt: TxCommand.time, policyVersion: 1))
        try ctx.save()
        try await TxStore.assertFailure(store, command: TxCommand.make(commandID: "2", transitionID: "2"),
                                       error: .duplicateLedgerLogicalKey(TxCommand.make().initialRewardKey))
    }
    func testDuplicateCommandReceiptCommitsNothing() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let ctx = ModelContext(store)
        for _ in 0..<2 {
            ctx.insert(BehaviorEventSD(transitionID: "transition:1", commandID: "command:1", targetID: TxCommand.target.rawValue,
                timestamp: TxCommand.time, kindRawValue: "completed", sourceRawValue: "test:v1"))
        }
        try ctx.save()
        try await TxStore.assertFailure(store, error: .duplicateCommandReceipt("command:1"))
    }
    func testReceiptIdentityReuseAndTransitionReuseFailWithoutMutation() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        _ = try await TxStore.service(store).complete(TxCommand.make())
        try await TxStore.assertFailure(store, command: TxCommand.make(targetID: TxCommand.other), error: .conflictingCommandReceipt("command:1"))
        try await TxStore.assertFailure(store, command: TxCommand.make(commandID: "other"), error: .conflictingTransitionID("transition:1"))
    }
    func testImmutableSnapshotConflictsCannotRewriteOccurrence() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        _ = try await TxStore.service(store).complete(TxCommand.make())
        for command in [TxCommand.make(commandID: "2", transitionID: "2", priority: .notUrgentAndNotImportant),
                        TxCommand.make(commandID: "2", transitionID: "2", type: .oneTime),
                        TxCommand.make(commandID: "2", transitionID: "2", eligibility: .ineligible)] {
            try await TxStore.assertFailure(store, command: command, error: .conflictingOccurrenceSnapshot(command.occurrenceID))
        }
        let original = TxCommand.make().occurrence
        let changed = BehaviorOccurrenceSnapshot(scheduledLocalDateKey: "different-day", scheduledAt: original.scheduledAt,
            dueAt: original.dueAt, schedulingTimeZoneIdentifier: original.schedulingTimeZoneIdentifier,
            schedulingCalendarIdentifier: original.schedulingCalendarIdentifier, scheduleRevisionID: original.scheduleRevisionID,
            iconName: original.iconName, notificationEnabled: original.notificationEnabled, streakBefore: original.streakBefore,
            provenance: original.provenance, predecessorOrAliasOccurrenceID: nil)
        try await TxStore.assertFailure(store, command: TxCommand.make(commandID: "2", transitionID: "2", snapshot: changed),
                                       error: .conflictingOccurrenceSnapshot(TxCommand.make().occurrenceID))
    }
    func testProfileArithmeticOverflowsAllRollBack() async throws {
        for field in ["xp", "coins", "earned"] {
            let store = try TxStore.memory(); try TxStore.seed(store)
            let ctx = ModelContext(store); let profile = try XCTUnwrap(ctx.fetch(FetchDescriptor<GamificationProfileSD>()).first)
            switch field {
            case "xp": profile.totalXP = Int.max
            case "coins": profile.honkerCoins = Int.max
            default: profile.lifetimeCoinsEarned = Int.max
            }
            try ctx.save()
            try await TxStore.assertFailure(store, error: .arithmeticOverflow)
        }
    }
    func testOccurrenceAndLegacyCountOverflowDoNotMutate() async throws {
        for occurrence in [true, false] {
            let store = try TxStore.memory(); try TxStore.seed(store)
            _ = try await TxStore.service(store).complete(TxCommand.make())
            let ctx = ModelContext(store)
            if occurrence { try XCTUnwrap(ctx.fetch(FetchDescriptor<TaskOccurrenceSD>()).first).completionCount = Int.max }
            else { try XCTUnwrap(ctx.fetch(FetchDescriptor<HabitRecordSD>()).first).count = Int.max }
            try ctx.save()
            try await TxStore.assertFailure(store, command: TxCommand.make(commandID: "2", transitionID: "2"), error: .arithmeticOverflow)
        }
    }
    func testCalculationAndLevelRangeErrorsCommitNothing() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        try await TxStore.assertFailure(store, command: TxCommand.make(policy: 999), error: .calculationFailure(.unsupportedPolicyVersion(999)))
        let ctx = ModelContext(store); let profile = try XCTUnwrap(ctx.fetch(FetchDescriptor<GamificationProfileSD>()).first)
        profile.totalXP = LevelCalculator().maximumSupportedTotalXP
        try ctx.save()
        try await TxStore.assertFailure(store, error: .calculationFailure(.totalXPOutOfRange(profile.totalXP + 41)))
    }
    func testFailureAfterEntireWriteSetIsStagedRollsBackEveryField() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let before = try TxStore.state(store)
        let actor = HabitsRepositorySwiftData(container: store)
        do {
            _ = try await actor.completeBehaviorForTesting(TxCommand.make(), transaction: BehaviorTransactionSD(gamificationService: TxCommand.gamification())) { context in
                XCTAssertTrue(context.hasChanges)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitRecordSD>()), 1)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskOccurrenceSD>()), 1)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorEventSD>()), 1)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 1)
                XCTAssertEqual(try context.fetch(FetchDescriptor<GamificationProfileSD>()).first?.totalXP, 41)
                throw NSError(domain: "BeforeSaveFixture", code: 42, userInfo: [NSLocalizedDescriptionKey: "injected"])
            }
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? BehaviorTransactionError, .persistenceFailure(domain: "BeforeSaveFixture", code: 42, message: "injected"))
        }
        XCTAssertEqual(try TxStore.state(store), before)
        _ = try await TxStore.service(store).complete(TxCommand.make()) // Failed staging did not leave a receipt behind.
    }
    func testActualReadOnlyStoreSaveFailureNeverReturnsSuccess() async throws {
        let dir = try Phase2TestStore.directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("readonly.store")
        try autoreleasepool { try TxStore.seed(TxStore.disk(url)) }
        let store = try TxStore.disk(url, allowsSave: false)
        let before = try TxStore.state(store)
        do { _ = try await TxStore.service(store).complete(TxCommand.make()); XCTFail("Read-only save must fail") }
        catch {
            guard case .persistenceFailure = error as? BehaviorTransactionError else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try TxStore.state(store), before)
    }
    func testTwoConcurrentHabitsShareActorAndAccumulateOneProfile() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let ctx = ModelContext(store); ctx.insert(HabitSD(id: TxCommand.other.rawValue)); try ctx.save()
        let service = TxStore.service(store)
        async let first = service.complete(TxCommand.make())
        async let second = service.complete(TxCommand.make(commandID: "2", transitionID: "2", targetID: TxCommand.other, occurrenceID: "other-occ"))
        let results = try await [first, second]
        XCTAssertEqual(results.count, 2)
        let fresh = ModelContext(store); let profile = try XCTUnwrap(fresh.fetch(FetchDescriptor<GamificationProfileSD>()).first)
        XCTAssertEqual(profile.totalXP, 82); XCTAssertEqual(profile.honkerCoins, 20); XCTAssertEqual(profile.lifetimeCoinsEarned, 20)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 2)
    }
    func testDuplicateLegacyDayRecordsFailSafely() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let ctx = ModelContext(store); let habit = try XCTUnwrap(ctx.fetch(FetchDescriptor<HabitSD>()).first)
        let a = HabitRecordSD(date: TxCommand.time, count: 1, habit: habit)
        let b = HabitRecordSD(date: TxCommand.time, count: 2, habit: habit)
        ctx.insert(a); ctx.insert(b); habit.records = [a, b]; try ctx.save()
        try await TxStore.assertFailure(store, error: .inconsistentStoredState("multiple legacy records in day"))
    }
}
