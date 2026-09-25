import Foundation

/// Already normalized facts. The caller owns occurrence identity and scheduling policy.
struct BehaviorCompletionCommand: Equatable, Sendable {
    let commandID: String
    let transitionID: String
    let profileKey: String
    let occurrenceID: String
    let completedAt: Date
    let legacyCompletionDate: Date
    /// Half-open [start, end) local-day boundaries supplied by the future planner.
    let legacyDay: DateInterval
    let rewardInput: GamificationRewardInput
    let occurrence: BehaviorOccurrenceSnapshot
    let source: String
    let predecessorTransitionID: String?

    var targetID: BehaviorTargetID { rewardInput.targetID }
    var initialRewardKey: String { "reward:v1:\(profileKey):\(occurrenceID):initial" }
}

struct BehaviorOccurrenceSnapshot: Equatable, Sendable {
    let scheduledLocalDateKey: String?
    let scheduledAt: Date?
    let dueAt: Date?
    let schedulingTimeZoneIdentifier: String?
    let schedulingCalendarIdentifier: String?
    let scheduleRevisionID: String?
    let iconName: String?
    let notificationEnabled: Bool?
    let streakBefore: Int
    let provenance: String
    let predecessorOrAliasOccurrenceID: String?
}

/// Retry responses contain only immutable receipt facts, not a fabricated historic balance.
struct BehaviorCommandReceipt: Equatable, Sendable {
    let commandID: String
    let transitionID: String
    let targetID: BehaviorTargetID
    let occurrenceID: String
    let completedAt: Date
    let completionCount: Int
}

enum BehaviorRewardDisposition: Equatable, Sendable {
    case granted(GamificationReward)
    case ineligible
    case alreadyRewarded(logicalKey: String)
}

struct BehaviorAppliedCompletion: Equatable, Sendable {
    let receipt: BehaviorCommandReceipt
    let legacyRecordID: UUID
    let legacyCompletionCount: Int
    let wasExistingOccurrence: Bool
    let reward: BehaviorRewardDisposition
    let resultingTotalXP: Int
    let resultingHonkerCoins: Int
    let resultingLevelProgress: LevelProgress
}

enum BehaviorTransactionResult: Equatable, Sendable {
    case applied(BehaviorAppliedCompletion)
    case duplicateCommand(BehaviorCommandReceipt)
}

enum BehaviorTransactionError: Error, Equatable, Sendable {
    case invalidCommand(String)
    case targetNotFound(BehaviorTargetID)
    case profileNotFound(String)
    case duplicateTarget(BehaviorTargetID)
    case duplicateProfileKey(String)
    case duplicateOccurrenceKey(String)
    case duplicateCommandReceipt(String)
    case duplicateLedgerLogicalKey(String)
    case conflictingCommandReceipt(String)
    case conflictingTransitionID(String)
    case conflictingOccurrenceSnapshot(String)
    case inconsistentStoredState(String)
    case arithmeticOverflow
    case calculationFailure(GamificationCalculationError)
    case persistenceFailure(domain: String, code: Int, message: String)
}
