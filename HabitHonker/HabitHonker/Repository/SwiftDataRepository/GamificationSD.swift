import Foundation
import SwiftData

/// Rebuildable balance cache, never the authoritative history. totalXP is NET XP.
/// No automatic enrollment: trackingStartedAt and policy timezone/calendar remain nil
/// until a future explicit enrollment operation. Level is derived, not persisted.
@Model
final class GamificationProfileSD {
    var id: UUID = UUID()
    var logicalProfileKey: String = ""
    var totalXP: Int = 0
    var honkerCoins: Int = 0
    var lifetimeCoinsEarned: Int = 0
    var lifetimeCoinsSpent: Int = 0
    var trackingStartedAt: Date? = nil
    var schedulingTimeZoneIdentifier: String? = nil
    var schedulingCalendarIdentifier: String? = nil
    var lastProcessedWeekKey: String? = nil
    var aggregateFingerprint: String? = nil
    var schemaVersion: Int = 1
    var updatedAt: Date? = nil

    init(
        id: UUID = UUID(),
        logicalProfileKey: String,
        totalXP: Int = 0,
        honkerCoins: Int = 0,
        lifetimeCoinsEarned: Int = 0,
        lifetimeCoinsSpent: Int = 0,
        trackingStartedAt: Date? = nil,
        schedulingTimeZoneIdentifier: String? = nil,
        schedulingCalendarIdentifier: String? = nil,
        lastProcessedWeekKey: String? = nil,
        aggregateFingerprint: String? = nil,
        schemaVersion: Int = 1,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.logicalProfileKey = logicalProfileKey
        self.totalXP = totalXP
        self.honkerCoins = honkerCoins
        self.lifetimeCoinsEarned = lifetimeCoinsEarned
        self.lifetimeCoinsSpent = lifetimeCoinsSpent
        self.trackingStartedAt = trackingStartedAt
        self.schedulingTimeZoneIdentifier = schedulingTimeZoneIdentifier
        self.schedulingCalendarIdentifier = schedulingCalendarIdentifier
        self.lastProcessedWeekKey = lastProcessedWeekKey
        self.aggregateFingerprint = aggregateFingerprint
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
    }
}

/// Append-only audit row: application code can initialize/read, but cannot change fields.
/// Scalar references preserve history independently of habit deletion. No uniqueness
/// promise or automatic deduplication: future transactions/reconciliation own that.
/// Snapshot fields are optional for predecessor-linked compensation rows. This model
/// stores supplied historical facts without calculating or repricing any reward.
/// SwiftData contexts can still delete rows; repository-level enforcement is deferred.
@Model
final class GamificationLedgerEntrySD {
    private(set) var id: UUID = UUID()
    private(set) var logicalKey: String = ""
    private(set) var profileKey: String = ""
    private(set) var targetID: UUID? = nil
    private(set) var occurrenceID: String? = nil
    private(set) var transitionID: String? = nil
    private(set) var xpDelta: Int = 0
    private(set) var coinDelta: Int = 0
    private(set) var reasonRawValue: String = ""
    private(set) var predecessorLogicalKey: String? = nil
    private(set) var createdAt: Date = Date(timeIntervalSince1970: 0)
    private(set) var schemaVersion: Int = 1
    private(set) var policyVersion: Int = 1
    private(set) var taskTypeRawValue: String? = nil
    private(set) var priorityRawValue: Int? = nil
    private(set) var streakAfterCompletion: Int? = nil
    private(set) var isOnTime: Bool? = nil
    private(set) var rewardEligibilityRawValue: String? = nil
    private(set) var baseXP: Int? = nil
    private(set) var baseCoins: Int? = nil
    private(set) var multiplierScale: Int? = nil
    private(set) var priorityMultiplier: Int? = nil
    private(set) var streakMultiplier: Int? = nil
    private(set) var timingMultiplier: Int? = nil
    private(set) var priorityCoinBonus: Int? = nil
    private(set) var streakCoinBonus: Int? = nil

    init(
        id: UUID = UUID(),
        logicalKey: String,
        profileKey: String,
        targetID: UUID?,
        occurrenceID: String?,
        transitionID: String? = nil,
        xpDelta: Int = 0,
        coinDelta: Int = 0,
        reasonRawValue: String,
        predecessorLogicalKey: String? = nil,
        createdAt: Date,
        schemaVersion: Int = 1,
        policyVersion: Int,
        taskTypeRawValue: String? = nil,
        priorityRawValue: Int? = nil,
        streakAfterCompletion: Int? = nil,
        isOnTime: Bool? = nil,
        rewardEligibilityRawValue: String? = nil,
        baseXP: Int? = nil,
        baseCoins: Int? = nil,
        multiplierScale: Int? = nil,
        priorityMultiplier: Int? = nil,
        streakMultiplier: Int? = nil,
        timingMultiplier: Int? = nil,
        priorityCoinBonus: Int? = nil,
        streakCoinBonus: Int? = nil
    ) {
        self.id = id
        self.logicalKey = logicalKey
        self.profileKey = profileKey
        self.targetID = targetID
        self.occurrenceID = occurrenceID
        self.transitionID = transitionID
        self.xpDelta = xpDelta
        self.coinDelta = coinDelta
        self.reasonRawValue = reasonRawValue
        self.predecessorLogicalKey = predecessorLogicalKey
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
        self.policyVersion = policyVersion
        self.taskTypeRawValue = taskTypeRawValue
        self.priorityRawValue = priorityRawValue
        self.streakAfterCompletion = streakAfterCompletion
        self.isOnTime = isOnTime
        self.rewardEligibilityRawValue = rewardEligibilityRawValue
        self.baseXP = baseXP
        self.baseCoins = baseCoins
        self.multiplierScale = multiplierScale
        self.priorityMultiplier = priorityMultiplier
        self.streakMultiplier = streakMultiplier
        self.timingMultiplier = timingMultiplier
        self.priorityCoinBonus = priorityCoinBonus
        self.streakCoinBonus = streakCoinBonus
    }
}
