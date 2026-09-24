import Foundation

/// Reward category only; recurrence/due-date interpretation belongs to behavior planning.
enum GamificationTaskType: String, Codable, Sendable {
    case repeating
    case oneTime
}

enum RewardEligibility: String, Codable, Sendable {
    case eligible
    case ineligible
}

/// Immutable snapshot supplied by a future occurrence planner, never a live HabitModel.
struct GamificationRewardInput: Equatable, Codable, Sendable {
    let targetID: BehaviorTargetID
    let taskType: GamificationTaskType
    let priority: BehaviorPriority
    
    /// Repeating tasks require a value >= 1.
    /// One-time tasks must use 0 because streak is not applicable.
    let streakAfterCompletion: Int
    
    let isOnTime: Bool
    let rewardEligibility: RewardEligibility
    let policyVersion: Int
}

struct GamificationReward: Equatable, Codable, Sendable {
    let xp: Int
    let honkerCoins: Int
    let input: GamificationRewardInput
    let breakdown: RewardCalculationBreakdown
}

/// Diagnostic basis of the reward calculation.
/// Modifier/bonus fields describe the calculated potential reward basis and may be non-zero
/// even when the final awarded XP/coins are zero because the input is ineligible.
/// Multipliers use integer hundredths in V1.
struct RewardCalculationBreakdown: Equatable, Codable, Sendable {
    let baseXP: Int
    let baseCoins: Int
    let multiplierScale: Int
    let priorityMultiplier: Int
    let streakMultiplier: Int
    let timingMultiplier: Int
    let priorityCoinBonus: Int
    let streakCoinBonus: Int
}

struct LevelProgress: Equatable, Sendable {
    let level: Int
    
    /// Negative supplied XP is normalized to zero. XP is never consumed on level-up.
    let totalXP: Int
    
    let xpEarnedWithinCurrentLevel: Int
    let xpRequiredForCurrentLevel: Int
    let xpRemainingToNextLevel: Int

    /// Presentation only: no floating-point value participates in level selection.
    var progressFraction: Double {
        Double(xpEarnedWithinCurrentLevel) / Double(xpRequiredForCurrentLevel)
    }
}

enum GamificationCalculationError: Error, Equatable, Sendable {
    case unsupportedPolicyVersion(Int)
    case invalidStreak(Int)
    case invalidLevel(Int)
    case totalXPOutOfRange(Int)
    case arithmeticOverflow
}
