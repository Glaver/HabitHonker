import Foundation
import XCTest
@testable import HabitHonker

final class GamificationServiceTests: XCTestCase {
    func testRewardDelegatesExactFrozenInputAndReturnsDependencyResult() throws {
        let input = frozenInput()
        let sentinel = GamificationReward(xp: 777, honkerCoins: 99, input: input,
            breakdown: RewardCalculationBreakdown(baseXP: 7, baseCoins: 8, multiplierScale: 100,
                priorityMultiplier: 101, streakMultiplier: 102, timingMultiplier: 103,
                priorityCoinBonus: 4, streakCoinBonus: 5))
        let service: any GamificationServiceProtocol = GamificationService(
            rewardCalculator: RewardStub(expected: input, result: sentinel), levelCalculator: RejectingLevelStub())
        XCTAssertEqual(try service.reward(for: input), sentinel)
    }

    func testLevelDelegatesRawTotalAndReturnsDependencyProgress() throws {
        let sentinel = LevelProgress(level: 42, totalXP: 99, xpEarnedWithinCurrentLevel: 2,
                                     xpRequiredForCurrentLevel: 10, xpRemainingToNextLevel: 8)
        let service = GamificationService(rewardCalculator: RejectingRewardStub(),
                                         levelCalculator: LevelStub(expected: -19, result: sentinel))
        XCTAssertEqual(try service.levelProgress(forTotalXP: -19), sentinel)
    }

    func testDependencyFailuresPropagateUnchanged() {
        let service = GamificationService(rewardCalculator: RejectingRewardStub(), levelCalculator: RejectingLevelStub())
        XCTAssertThrowsError(try service.reward(for: frozenInput())) { XCTAssertEqual($0 as? StubError, .sentinel) }
        XCTAssertThrowsError(try service.levelProgress(forTotalXP: 10)) { XCTAssertEqual($0 as? StubError, .sentinel) }
    }

    func testFreshServicesAreIndependentAndRepeatable() throws {
        let first = GamificationService(rewardCalculator: RewardCalculator(), levelCalculator: LevelCalculator())
        let second = GamificationService(rewardCalculator: RewardCalculator(), levelCalculator: LevelCalculator())
        let frozen = frozenInput()
        let expected = try first.reward(for: frozen)
        for _ in 0..<10 {
            XCTAssertEqual(try second.reward(for: frozen), expected)
            XCTAssertEqual(try first.levelProgress(forTotalXP: 180), try second.levelProgress(forTotalXP: 180))
        }
    }

    func testPureSourceBoundaryHasNoClockLocaleUIOrPersistenceDependency() throws {
        // Architecture guard complements the arithmetic tests without changing process timezone/locale.
        let core = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HabitHonker/Core")
        let paths = ["Domain/GamificationModels.swift", "Gamification/GamificationPolicy.swift",
                     "Gamification/RewardCalculator.swift", "Gamification/LevelCalculator.swift",
                     "Gamification/GamificationService.swift", "Protocols/RewardCalculating.swift",
                     "Protocols/LevelCalculating.swift", "Protocols/GamificationServiceProtocol.swift"]
        for path in paths {
            let source = try String(contentsOf: core.appendingPathComponent(path), encoding: .utf8)
            let imports = source.split(separator: "\n").filter { $0.hasPrefix("import ") }
            XCTAssertTrue(imports.allSatisfy { $0 == "import Foundation" }, path)
            // Comments may describe exclusions; examine source expressions, not prose.
            let code = source.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for forbidden in ["Date()", "Calendar.current", "Locale.current", "TimeZone.current",
                              "ModelContext", "UserDefaults", "NotificationCenter", "HabitEventCenter",
                              "HabitModel", "pow(", "static var "] {
                XCTAssertFalse(code.contains(forbidden), "\(path): \(forbidden)")
            }
        }
    }

    private func frozenInput() -> GamificationRewardInput {
        GamificationRewardInput(targetID: BehaviorTargetID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!),
            taskType: .oneTime, priority: .importantAndUrgent, streakAfterCompletion: 0,
            isOnTime: true, rewardEligibility: .eligible, policyVersion: 1)
    }
}

private enum StubError: Error { case sentinel, unexpectedArgument }
private struct RewardStub: RewardCalculating {
    let expected: GamificationRewardInput
    let result: GamificationReward
    func reward(for input: GamificationRewardInput) throws -> GamificationReward {
        guard input == expected else { throw StubError.unexpectedArgument }
        return result
    }
}
private struct LevelStub: LevelCalculating {
    let expected: Int
    let result: LevelProgress
    func level(forTotalXP totalXP: Int) throws -> Int { throw StubError.unexpectedArgument }
    func xpRequiredToAdvance(from level: Int) throws -> Int { throw StubError.unexpectedArgument }
    func progress(forTotalXP totalXP: Int) throws -> LevelProgress {
        guard totalXP == expected else { throw StubError.unexpectedArgument }
        return result
    }
}
private struct RejectingRewardStub: RewardCalculating {
    func reward(for input: GamificationRewardInput) throws -> GamificationReward { throw StubError.sentinel }
}
private struct RejectingLevelStub: LevelCalculating {
    func level(forTotalXP totalXP: Int) throws -> Int { throw StubError.sentinel }
    func xpRequiredToAdvance(from level: Int) throws -> Int { throw StubError.sentinel }
    func progress(forTotalXP totalXP: Int) throws -> LevelProgress { throw StubError.sentinel }
}
