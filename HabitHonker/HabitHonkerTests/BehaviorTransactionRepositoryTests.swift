import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

@MainActor
final class BehaviorTransactionRepositoryTests: XCTestCase {
    func testEligibleWriteSetAndFrozenRewardFixture() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let c = TxCommand.make()
        let result = try await TxStore.service(store).complete(c)
        let applied = try TxStore.applied(result)
        XCTAssertEqual(applied.receipt.completionCount, 1)
        XCTAssertEqual(applied.legacyCompletionCount, 1)
        XCTAssertFalse(applied.wasExistingOccurrence)
        guard case let .granted(reward) = applied.reward else { return XCTFail("Expected reward") }
        XCTAssertEqual(reward.input, c.rewardInput)
        XCTAssertEqual(reward.xp, 41); XCTAssertEqual(reward.honkerCoins, 10)
        let ctx = ModelContext(store)
        let habit = try XCTUnwrap(ctx.fetch(FetchDescriptor<HabitSD>()).first)
        XCTAssertEqual(habit.title, "Mutable title"); XCTAssertEqual(habit.priorityRaw, 3)
        let record = try XCTUnwrap(habit.records?.first)
        XCTAssertEqual(record.count, 1); XCTAssertEqual(record.date, c.legacyCompletionDate)
        XCTAssertEqual(record.id, applied.legacyRecordID)
        let o = try XCTUnwrap(ctx.fetch(FetchDescriptor<TaskOccurrenceSD>()).first)
        XCTAssertEqual(o.targetID, c.targetID.rawValue); XCTAssertEqual(o.logicalOccurrenceID, c.occurrenceID)
        XCTAssertEqual(o.taskTypeRawValue, "repeating"); XCTAssertEqual(o.statusRawValue, "completed")
        XCTAssertEqual(o.completedAt, c.completedAt); XCTAssertEqual(o.completionCount, 1)
        XCTAssertEqual(o.priorityRawValue, c.rewardInput.priority.rawValue)
        XCTAssertEqual(o.scheduledAt, c.occurrence.scheduledAt); XCTAssertEqual(o.dueAt, c.occurrence.dueAt)
        XCTAssertEqual(o.scheduledLocalDateKey, c.occurrence.scheduledLocalDateKey)
        XCTAssertEqual(o.schedulingTimeZoneIdentifier, c.occurrence.schedulingTimeZoneIdentifier)
        XCTAssertEqual(o.schedulingCalendarIdentifier, c.occurrence.schedulingCalendarIdentifier)
        XCTAssertEqual(o.scheduleRevisionID, c.occurrence.scheduleRevisionID)
        XCTAssertEqual(o.iconName, c.occurrence.iconName); XCTAssertEqual(o.notificationEnabled, true)
        XCTAssertEqual(o.streakBefore, 6); XCTAssertEqual(o.streakAfter, 7)
        XCTAssertEqual(o.rewardEligibilityRawValue, "eligible"); XCTAssertEqual(o.provenanceRawValue, "native:v1")
        XCTAssertEqual(o.legacyRecordID, record.id); XCTAssertNil(o.predecessorOrAliasOccurrenceID)
        let event = try XCTUnwrap(ctx.fetch(FetchDescriptor<BehaviorEventSD>()).first)
        XCTAssertEqual(event.commandID, c.commandID); XCTAssertEqual(event.transitionID, c.transitionID)
        XCTAssertEqual(event.targetID, c.targetID.rawValue); XCTAssertEqual(event.occurrenceID, c.occurrenceID)
        XCTAssertEqual(event.timestamp, c.completedAt); XCTAssertEqual(event.kindRawValue, "completed")
        XCTAssertEqual(event.completionCount, 1); XCTAssertEqual(event.sourceRawValue, c.source)
        XCTAssertEqual(event.provenanceRawValue, c.occurrence.provenance); XCTAssertNil(event.predecessorTransitionID)
        let ledger = try XCTUnwrap(ctx.fetch(FetchDescriptor<GamificationLedgerEntrySD>()).first)
        XCTAssertEqual(ledger.logicalKey, c.initialRewardKey); XCTAssertEqual(ledger.profileKey, c.profileKey)
        XCTAssertEqual(ledger.targetID, c.targetID.rawValue); XCTAssertEqual(ledger.occurrenceID, c.occurrenceID)
        XCTAssertEqual(ledger.transitionID, c.transitionID); XCTAssertEqual(ledger.createdAt, c.completedAt)
        XCTAssertEqual(ledger.xpDelta, 41); XCTAssertEqual(ledger.coinDelta, 10)
        XCTAssertEqual(ledger.reasonRawValue, "completion"); XCTAssertNil(ledger.predecessorLogicalKey)
        XCTAssertEqual(ledger.taskTypeRawValue, "repeating"); XCTAssertEqual(ledger.priorityRawValue, 2)
        XCTAssertEqual(ledger.streakAfterCompletion, 7); XCTAssertEqual(ledger.isOnTime, true)
        XCTAssertEqual(ledger.rewardEligibilityRawValue, "eligible"); XCTAssertEqual(ledger.policyVersion, 1)
        XCTAssertEqual(ledger.baseXP, 25); XCTAssertEqual(ledger.baseCoins, 3); XCTAssertEqual(ledger.multiplierScale, 100)
        XCTAssertEqual(ledger.priorityMultiplier, 130); XCTAssertEqual(ledger.streakMultiplier, 115)
        XCTAssertEqual(ledger.timingMultiplier, 110); XCTAssertEqual(ledger.priorityCoinBonus, 2); XCTAssertEqual(ledger.streakCoinBonus, 5)
        let profile = try XCTUnwrap(ctx.fetch(FetchDescriptor<GamificationProfileSD>()).first)
        XCTAssertEqual(profile.totalXP, 41); XCTAssertEqual(profile.honkerCoins, 10)
        XCTAssertEqual(profile.lifetimeCoinsEarned, 10); XCTAssertEqual(profile.lifetimeCoinsSpent, 0)
        XCTAssertEqual(profile.updatedAt, c.completedAt); XCTAssertEqual(profile.trackingStartedAt, TxCommand.time)
        XCTAssertEqual(applied.resultingTotalXP, 41); XCTAssertEqual(applied.resultingHonkerCoins, 10)
        XCTAssertEqual(applied.resultingLevelProgress, try TxCommand.gamification().levelProgress(forTotalXP: 41))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 0)
        for version in [o.schemaVersion, event.schemaVersion, ledger.schemaVersion, profile.schemaVersion] { XCTAssertEqual(version, 1) }
    }

    func testRetryIsDurableNoOpAndReturnsStableReceiptAfterFurtherCounts() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let command = TxCommand.make()
        let first = try TxStore.applied(await TxStore.service(store).complete(command))
        let before = try TxStore.state(store)
        let retry = try await TxStore.service(store).complete(command)
        XCTAssertEqual(retry, .duplicateCommand(first.receipt))
        XCTAssertEqual(try TxStore.state(store), before)
        _ = try await TxStore.service(store).complete(TxCommand.make(commandID: "2", transitionID: "2"))
        let afterSecond = try TxStore.state(store)
        let retryAgain = try await TxStore.service(store).complete(command)
        XCTAssertEqual(retryAgain, retry)
        XCTAssertEqual(try TxStore.state(store), afterSecond)
    }

    func testNewCommandSameOccurrenceIncrementsCountsWithoutRepricingPolicy() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        _ = try await TxStore.service(store).complete(TxCommand.make())
        let original = try TxStore.state(store).filter { $0.key.hasPrefix("Gamification") }
        let result = try TxStore.applied(await TxStore.service(store).complete(
            TxCommand.make(commandID: "2", transitionID: "2", policy: 999)))
        XCTAssertEqual(result.receipt.completionCount, 2); XCTAssertEqual(result.legacyCompletionCount, 2)
        XCTAssertEqual(result.reward, .alreadyRewarded(logicalKey: TxCommand.make().initialRewardKey))
        XCTAssertEqual(try TxStore.state(store).filter { $0.key.hasPrefix("Gamification") }, original)
        let ctx = ModelContext(store)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<BehaviorEventSD>()), 2)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 1)
    }

    func testOnDiskRecreationRetainsCommandAndEntitlementIdempotency() async throws {
        let dir = try Phase2TestStore.directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("transaction.store")
        try await firstDiskCompletion(url)
        let store = try TxStore.disk(url)
        let service = TxStore.service(store)
        let retry = try await service.complete(TxCommand.make())
        guard case .duplicateCommand = retry else { return XCTFail("Not durable") }
        let second = try TxStore.applied(await service.complete(TxCommand.make(commandID: "2", transitionID: "2")))
        XCTAssertEqual(second.receipt.completionCount, 2); XCTAssertEqual(second.resultingTotalXP, 41)
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 1)
    }

    private func firstDiskCompletion(_ url: URL) async throws {
        let store = try TxStore.disk(url); try TxStore.seed(store)
        _ = try await TxStore.service(store).complete(TxCommand.make())
    }

    func testIneligibleWritesOnlyBehaviorAndLeavesProfileByteFactsUnchanged() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let before = try TxStore.state(store).filter { $0.key.hasPrefix("GamificationProfileSD") }
        let c = TxCommand.make(eligibility: .ineligible)
        let result = try TxStore.applied(await TxStore.service(store).complete(c))
        XCTAssertEqual(result.reward, .ineligible)
        let ctx = ModelContext(store)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<HabitRecordSD>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<TaskOccurrenceSD>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<BehaviorEventSD>()), 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 0)
        XCTAssertEqual(try TxStore.state(store).filter { $0.key.hasPrefix("GamificationProfileSD") }, before)
    }

    func testOneTimeLaterDayCountDoesNotGrantAgain() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let service = TxStore.service(store)
        _ = try await service.complete(TxCommand.make(occurrenceID: "occ:v1:task:once", type: .oneTime))
        let result = try TxStore.applied(await service.complete(TxCommand.make(commandID: "2", transitionID: "2",
            occurrenceID: "occ:v1:task:once", type: .oneTime, date: TxCommand.time.addingTimeInterval(90000))))
        XCTAssertEqual(result.receipt.completionCount, 2); XCTAssertEqual(result.legacyCompletionCount, 1)
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<HabitRecordSD>()), 2)
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 1)
    }

    func testLegacyHalfOpenDayIncrementsExistingRecordAndPreservesTimestamp() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let c = TxCommand.make(); let ctx = ModelContext(store)
        let habit = try XCTUnwrap(ctx.fetch(FetchDescriptor<HabitSD>()).first)
        let start = HabitRecordSD(date: c.legacyDay.start, count: 4, habit: habit)
        let end = HabitRecordSD(date: c.legacyDay.end, count: 7, habit: habit)
        ctx.insert(start); ctx.insert(end); habit.records = [start, end]; try ctx.save()
        let result = try TxStore.applied(await TxStore.service(store).complete(c))
        XCTAssertEqual(result.legacyRecordID, start.id); XCTAssertEqual(result.legacyCompletionCount, 5)
        let rows = try ModelContext(store).fetch(FetchDescriptor<HabitRecordSD>())
        XCTAssertEqual(rows.first { $0.id == start.id }?.date, c.legacyDay.start)
        XCTAssertEqual(rows.first { $0.id == end.id }?.count, 7)
    }

    func testInjectedGamificationControlsAmountsAndReceivesFrozenInput() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store)
        let command = TxCommand.make()
        let result = try TxStore.applied(await TxStore.service(store, gamification: SentinelGamification(expected: command.rewardInput)).complete(command))
        XCTAssertEqual(result.resultingTotalXP, 9); XCTAssertEqual(result.resultingHonkerCoins, 4)
        let ledger = try XCTUnwrap(ModelContext(store).fetch(FetchDescriptor<GamificationLedgerEntrySD>()).first)
        XCTAssertEqual(ledger.xpDelta, 9); XCTAssertEqual(ledger.coinDelta, 4); XCTAssertEqual(ledger.baseXP, 123)
    }
}

private struct SentinelGamification: GamificationServiceProtocol {
    let expected: GamificationRewardInput
    func reward(for input: GamificationRewardInput) throws -> GamificationReward {
        XCTAssertEqual(input, expected)
        return GamificationReward(xp: 9, honkerCoins: 4, input: input,
            breakdown: RewardCalculationBreakdown(baseXP: 123, baseCoins: 321, multiplierScale: 100,
                priorityMultiplier: 1, streakMultiplier: 2, timingMultiplier: 3, priorityCoinBonus: 4, streakCoinBonus: 5))
    }
    func levelProgress(forTotalXP totalXP: Int) throws -> LevelProgress {
        try LevelCalculator().progress(forTotalXP: totalXP)
    }
}
