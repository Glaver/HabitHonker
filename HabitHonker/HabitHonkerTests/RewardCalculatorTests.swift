import Foundation
import XCTest
@testable import HabitHonker

final class RewardCalculatorTests: XCTestCase {
    private let calculator = RewardCalculator()

    func testBaseRewardsForBothTaskTypes() throws {
        let repeating = try calculator.reward(for: input())
        XCTAssertEqual(repeating.xp, 25)
        XCTAssertEqual(repeating.honkerCoins, 3)
        let once = try calculator.reward(for: input(type: .oneTime, streak: 0))
        XCTAssertEqual(once.xp, 40)
        XCTAssertEqual(once.honkerCoins, 5)
    }

    func testEveryPriorityForBothTypes() throws {
        let cases: [(BehaviorPriority, Int, Int, Int, Int)] = [
            (.importantButNotUrgent, 130, 2, 33, 52),
            (.importantAndUrgent, 120, 1, 30, 48),
            (.urgentButNotImportant, 110, 0, 28, 44),
            (.notUrgentAndNotImportant, 100, 0, 25, 40)
        ]
        for (priority, multiplier, bonus, repeatingXP, onceXP) in cases {
            for type in [GamificationTaskType.repeating, .oneTime] {
                let result = try calculator.reward(for: input(type: type, priority: priority))
                XCTAssertEqual(result.xp, type == .repeating ? repeatingXP : onceXP)
                XCTAssertEqual(result.honkerCoins, (type == .repeating ? 3 : 5) + bonus)
                XCTAssertEqual(result.breakdown.priorityMultiplier, multiplier)
                XCTAssertEqual(result.breakdown.priorityCoinBonus, bonus)
            }
        }
    }

    func testEveryStreakBoundary() throws {
        let cases = [(1,100), (2,105), (3,105), (4,110), (6,110), (7,115),
                     (13,115), (14,120), (29,120), (30,125), (59,125),
                     (60,125), (99,125), (100,125), (101,125), (Int.max,125)]
        for (streak, multiplier) in cases {
            let result = try calculator.reward(for: input(streak: streak))
            XCTAssertEqual(result.breakdown.streakMultiplier, multiplier, "streak \(streak)")
        }
    }

    func testMilestonesAndAdjacentValues() throws {
        for (streak, coins) in [(3,2), (7,5), (14,8), (30,15), (60,25), (100,50)] {
            let result = try calculator.reward(for: input(streak: streak))
            XCTAssertEqual(result.breakdown.streakCoinBonus, coins)
            XCTAssertEqual(result.honkerCoins, 3 + coins)
        }
        for streak in [2,4,6,8,13,15,29,31,59,61,99,101] {
            let result = try calculator.reward(for: input(streak: streak))
            XCTAssertEqual(result.breakdown.streakCoinBonus, 0)
            XCTAssertEqual(result.honkerCoins, 3)
        }
    }

    func testOneTimeRequiresZeroStreakAndHasNoStreakModifiers() throws {
        let result = try calculator.reward(for: input(type: .oneTime, streak: 0))
        XCTAssertEqual(result.xp, 40)
        XCTAssertEqual(result.honkerCoins, 5)
        XCTAssertEqual(result.breakdown.streakMultiplier, 100)
        XCTAssertEqual(result.breakdown.streakCoinBonus, 0)
        for streak in [Int.min, -1, 1, 2, 3, 7, 14, 30, 60, 100, Int.max] {
            for eligibility in [RewardEligibility.eligible, .ineligible] {
                XCTAssertThrowsError(try calculator.reward(for: input(type: .oneTime, streak: streak, eligibility: eligibility))) {
                    XCTAssertEqual($0 as? GamificationCalculationError, .invalidStreak(streak))
                }
            }
        }
    }

    func testTimingAndCoinsAreIndependent() throws {
        let late = try calculator.reward(for: input(priority: .importantButNotUrgent, streak: 7))
        let onTime = try calculator.reward(for: input(priority: .importantButNotUrgent, streak: 7, onTime: true))
        XCTAssertEqual(late.xp, 37)
        XCTAssertEqual(onTime.xp, 41)
        XCTAssertEqual(late.honkerCoins, 10)
        XCTAssertEqual(onTime.honkerCoins, 10)
        XCTAssertEqual(late.breakdown.timingMultiplier, 100)
        XCTAssertEqual(onTime.breakdown.timingMultiplier, 110)
    }

    func testRequiredExamplesAndSingleFinalHalfUpRounding() throws {
        let repeating = try calculator.reward(for: input(priority: .importantButNotUrgent, onTime: true))
        XCTAssertEqual(repeating.xp, 36)
        XCTAssertEqual(repeating.honkerCoins, 5)
        let once = try calculator.reward(for: input(type: .oneTime, priority: .importantAndUrgent, onTime: true))
        XCTAssertEqual(once.xp, 53)
        XCTAssertEqual(once.honkerCoins, 6)
        // 25*1.30*1.05 = 34.125 -> 34; rounding 32.5 first would incorrectly yield 35.
        XCTAssertEqual(try calculator.reward(for: input(priority: .importantButNotUrgent, streak: 2)).xp, 34)
        // Exact half 25*1.10 = 27.5 must round UP, not ties-to-even/away by accident.
        XCTAssertEqual(try calculator.reward(for: input(priority: .urgentButNotImportant)).xp, 28)
        XCTAssertEqual(try calculator.reward(for: input(priority: .importantButNotUrgent)).xp, 33)
    }

    func testIneligibleInputReturnsNoXPOrCoinsIncludingMilestone() throws {
        let frozen = input(priority: .importantButNotUrgent, streak: 100, onTime: true, eligibility: .ineligible)
        let result = try calculator.reward(for: frozen)
        XCTAssertEqual(result.xp, 0)
        XCTAssertEqual(result.honkerCoins, 0)
        XCTAssertEqual(result.input, frozen)
        XCTAssertEqual(result.breakdown.streakCoinBonus, 50, "Diagnostics describe potential modifiers, not granted coins")
    }

    func testInvalidInputAndUnknownPolicyAreRejected() {
        for streak in [Int.min, -1, 0] {
            XCTAssertThrowsError(try calculator.reward(for: input(streak: streak))) {
                XCTAssertEqual($0 as? GamificationCalculationError, .invalidStreak(streak))
            }
        }
        XCTAssertThrowsError(try calculator.reward(for: input(type: .oneTime, streak: -1)))
        for version in [0,2,Int.max] {
            XCTAssertThrowsError(try calculator.reward(for: input(version: version))) {
                XCTAssertEqual($0 as? GamificationCalculationError, .unsupportedPolicyVersion(version))
            }
        }
    }

    func testFrozenInputRoundTripAndRepeatedEvaluationAreIdentical() throws {
        let frozen = input(priority: .importantButNotUrgent, streak: 14, onTime: true)
        let decoded = try JSONDecoder().decode(GamificationRewardInput.self, from: JSONEncoder().encode(frozen))
        let expected = try calculator.reward(for: frozen)
        for _ in 0..<20 {
            XCTAssertEqual(try RewardCalculator().reward(for: decoded), expected)
        }
        XCTAssertEqual(try JSONDecoder().decode(GamificationReward.self, from: JSONEncoder().encode(expected)), expected)
    }

    private func input(type: GamificationTaskType = .repeating,
                       priority: BehaviorPriority = .notUrgentAndNotImportant,
                       streak: Int? = nil, onTime: Bool = false,
                       eligibility: RewardEligibility = .eligible, version: Int = 1) -> GamificationRewardInput {
        GamificationRewardInput(targetID: BehaviorTargetID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!),
                                taskType: type, priority: priority, streakAfterCompletion: streak ?? (type == .repeating ? 1 : 0),
                                isOnTime: onTime, rewardEligibility: eligibility, policyVersion: version)
    }
}
