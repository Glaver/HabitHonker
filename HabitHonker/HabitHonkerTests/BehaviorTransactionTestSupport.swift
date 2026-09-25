import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

enum TxCommand {
    static let target = BehaviorTargetID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
    static let other = BehaviorTargetID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
    static let time = Date(timeIntervalSince1970: 1_800_000_000)
    static func make(commandID: String = "command:1", transitionID: String = "transition:1",
                     targetID: BehaviorTargetID = target, occurrenceID: String = "occ:v1:task:day:2027-01-15",
                     type: GamificationTaskType = .repeating, priority: BehaviorPriority = .importantButNotUrgent,
                     eligibility: RewardEligibility = .eligible, policy: Int = 1,
                     date: Date = time, snapshot: BehaviorOccurrenceSnapshot? = nil) -> BehaviorCompletionCommand {
        BehaviorCompletionCommand(commandID: commandID, transitionID: transitionID, profileKey: "profile:v1:default",
            occurrenceID: occurrenceID, completedAt: date, legacyCompletionDate: date,
            legacyDay: DateInterval(start: date.addingTimeInterval(-100), duration: 1000),
            rewardInput: GamificationRewardInput(targetID: targetID, taskType: type, priority: priority,
                streakAfterCompletion: type == .oneTime ? 0 : 7, isOnTime: true,
                rewardEligibility: eligibility, policyVersion: policy),
            occurrence: snapshot ?? BehaviorOccurrenceSnapshot(scheduledLocalDateKey: "2027-01-15",
                scheduledAt: time.addingTimeInterval(-10), dueAt: time.addingTimeInterval(100),
                schedulingTimeZoneIdentifier: "America/Los_Angeles", schedulingCalendarIdentifier: "gregorian",
                scheduleRevisionID: "revision:1", iconName: "biceps-flexed", notificationEnabled: true,
                streakBefore: type == .oneTime ? 0 : 6, provenance: "native:v1", predecessorOrAliasOccurrenceID: nil),
            source: "test:v1", predecessorTransitionID: nil)
    }
    static func gamification() -> GamificationService {
        GamificationService(rewardCalculator: RewardCalculator(), levelCalculator: LevelCalculator())
    }
}

@MainActor
enum TxStore {
    static func memory() throws -> ModelContainer {
        let schema = Schema(versionedSchema: HabitHonkerSchemaV2.self)
        return try ModelContainer(for: schema, migrationPlan: HabitHonkerMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }
    static func disk(_ url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = Schema(versionedSchema: HabitHonkerSchemaV2.self)
        return try ModelContainer(for: schema, migrationPlan: HabitHonkerMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none))
    }
    static func seed(_ container: ModelContainer, habit: Bool = true, profile: Bool = true) throws {
        let context = ModelContext(container)
        if habit {
            // Mutable metadata intentionally differs from the command's historical facts.
            context.insert(HabitSD(id: TxCommand.target.rawValue, icon: "bed", title: "Mutable title", priorityRaw: 3,
                                  typeRaw: HabitType.dueDate.rawValue, notificationActivated: false))
        }
        if profile {
            context.insert(GamificationProfileSD(logicalProfileKey: "profile:v1:default", trackingStartedAt: TxCommand.time,
                schedulingTimeZoneIdentifier: "America/Los_Angeles", schedulingCalendarIdentifier: "gregorian"))
        }
        try context.save()
    }
    static func service(_ container: ModelContainer,
                        gamification: any GamificationServiceProtocol = TxCommand.gamification()) -> BehaviorTransactionService {
        BehaviorTransactionService(repository: SwiftDataBehaviorTransactionRepository(
            repository: HabitsRepositorySwiftData(container: container), gamificationService: gamification))
    }
    static func applied(_ result: BehaviorTransactionResult, file: StaticString = #filePath, line: UInt = #line) throws -> BehaviorAppliedCompletion {
        guard case let .applied(value) = result else {
            XCTFail("Expected applied", file: file, line: line)
            throw BehaviorTransactionError.invalidCommand("test result")
        }
        return value
    }
    static func assertFailure(_ container: ModelContainer, command: BehaviorCompletionCommand = TxCommand.make(),
                              error expected: BehaviorTransactionError, file: StaticString = #filePath, line: UInt = #line) async throws {
        let before = try state(container)
        do { _ = try await service(container).complete(command); XCTFail("Expected failure", file: file, line: line) }
        catch { XCTAssertEqual(error as? BehaviorTransactionError, expected, file: file, line: line) }
        XCTAssertEqual(try state(container), before, "Failure changed durable state", file: file, line: line)
    }
    static func state(_ container: ModelContainer) throws -> [String: [String: AnyHashable?]] {
        let context = ModelContext(container)
        var result = try Phase2TestStore.legacySnapshot(context)
        for row in try context.fetch(FetchDescriptor<TaskOccurrenceSD>()) {
            result["TaskOccurrenceSD:\(row.id)"] = [
                "id": row.id,
                "logicalOccurrenceID": row.logicalOccurrenceID,
                "targetID": row.targetID,
                "scheduledLocalDateKey": row.scheduledLocalDateKey,
                "scheduledAt": row.scheduledAt,
                "dueAt": row.dueAt,
                "schedulingTimeZoneIdentifier": row.schedulingTimeZoneIdentifier,
                "schedulingCalendarIdentifier": row.schedulingCalendarIdentifier,
                "taskTypeRawValue": row.taskTypeRawValue,
                "statusRawValue": row.statusRawValue,
                "completedAt": row.completedAt,
                "completionCount": row.completionCount,
                "scheduleRevisionID": row.scheduleRevisionID,
                "priorityRawValue": row.priorityRawValue,
                "iconName": row.iconName,
                "notificationEnabled": row.notificationEnabled,
                "streakBefore": row.streakBefore,
                "streakAfter": row.streakAfter,
                "rewardEligibilityRawValue": row.rewardEligibilityRawValue,
                "legacyRecordID": row.legacyRecordID,
                "provenanceRawValue": row.provenanceRawValue,
                "predecessorOrAliasOccurrenceID": row.predecessorOrAliasOccurrenceID,
                "schemaVersion": row.schemaVersion
            ]
        }
        for row in try context.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>()) {
            result["BehaviorScheduleRevisionSD:\(row.id)"] = [
                "id": row.id,
                "logicalRevisionID": row.logicalRevisionID,
                "targetID": row.targetID,
                "effectiveFrom": row.effectiveFrom,
                "effectiveTo": row.effectiveTo,
                "taskTypeRawValue": row.taskTypeRawValue,
                "selectedWeekdaysMask": row.selectedWeekdaysMask,
                "scheduledHour": row.scheduledHour,
                "scheduledMinute": row.scheduledMinute,
                "dueAt": row.dueAt,
                "schedulingTimeZoneIdentifier": row.schedulingTimeZoneIdentifier,
                "schedulingCalendarIdentifier": row.schedulingCalendarIdentifier,
                "priorityRawValue": row.priorityRawValue,
                "iconName": row.iconName,
                "notificationEnabled": row.notificationEnabled,
                "schemaVersion": row.schemaVersion
            ]
        }
        for row in try context.fetch(FetchDescriptor<BehaviorEventSD>()) {
            result["BehaviorEventSD:\(row.id)"] = [
                "id": row.id,
                "transitionID": row.transitionID,
                "commandID": row.commandID,
                "targetID": row.targetID,
                "occurrenceID": row.occurrenceID,
                "timestamp": row.timestamp,
                "kindRawValue": row.kindRawValue,
                "completionCount": row.completionCount,
                "predecessorTransitionID": row.predecessorTransitionID,
                "sourceRawValue": row.sourceRawValue,
                "provenanceRawValue": row.provenanceRawValue,
                "schemaVersion": row.schemaVersion
            ]
        }
        for row in try context.fetch(FetchDescriptor<GamificationProfileSD>()) {
            result["GamificationProfileSD:\(row.id)"] = [
                "id": row.id,
                "logicalProfileKey": row.logicalProfileKey,
                "totalXP": row.totalXP,
                "honkerCoins": row.honkerCoins,
                "lifetimeCoinsEarned": row.lifetimeCoinsEarned,
                "lifetimeCoinsSpent": row.lifetimeCoinsSpent,
                "trackingStartedAt": row.trackingStartedAt,
                "schedulingTimeZoneIdentifier": row.schedulingTimeZoneIdentifier,
                "schedulingCalendarIdentifier": row.schedulingCalendarIdentifier,
                "lastProcessedWeekKey": row.lastProcessedWeekKey,
                "aggregateFingerprint": row.aggregateFingerprint,
                "schemaVersion": row.schemaVersion,
                "updatedAt": row.updatedAt
            ]
        }
        for row in try context.fetch(FetchDescriptor<GamificationLedgerEntrySD>()) {
            result["GamificationLedgerEntrySD:\(row.id)"] = [
                "id": row.id,
                "logicalKey": row.logicalKey,
                "profileKey": row.profileKey,
                "targetID": row.targetID,
                "occurrenceID": row.occurrenceID,
                "transitionID": row.transitionID,
                "xpDelta": row.xpDelta,
                "coinDelta": row.coinDelta,
                "reasonRawValue": row.reasonRawValue,
                "predecessorLogicalKey": row.predecessorLogicalKey,
                "createdAt": row.createdAt,
                "schemaVersion": row.schemaVersion,
                "policyVersion": row.policyVersion,
                "taskTypeRawValue": row.taskTypeRawValue,
                "priorityRawValue": row.priorityRawValue,
                "streakAfterCompletion": row.streakAfterCompletion,
                "isOnTime": row.isOnTime,
                "rewardEligibilityRawValue": row.rewardEligibilityRawValue,
                "baseXP": row.baseXP,
                "baseCoins": row.baseCoins,
                "multiplierScale": row.multiplierScale,
                "priorityMultiplier": row.priorityMultiplier,
                "streakMultiplier": row.streakMultiplier,
                "timingMultiplier": row.timingMultiplier,
                "priorityCoinBonus": row.priorityCoinBonus,
                "streakCoinBonus": row.streakCoinBonus
            ]
        }
        return result
    }
}
