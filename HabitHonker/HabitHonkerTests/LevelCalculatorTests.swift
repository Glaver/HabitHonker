import XCTest
@testable import HabitHonker

final class LevelCalculatorTests: XCTestCase {
    private let calculator = LevelCalculator()

    func testRequiredThresholdExamples() throws {
        for (level, xp) in [(1,80), (2,100), (3,125), (5,180), (10,325),
                            (20,680), (30,1095), (40,1565), (50,2070)] {
            XCTAssertEqual(try calculator.xpRequiredToAdvance(from: level), xp, "level \(level)")
        }
    }

    func testCumulativeLevelsDoNotConsumeXP() throws {
        for (xp, level) in [(0,1), (79,1), (80,2), (179,2), (180,3)] {
            XCTAssertEqual(try calculator.level(forTotalXP: xp), level)
            XCTAssertEqual(try calculator.progress(forTotalXP: xp).totalXP, xp)
        }
    }

    func testProgressAtAllRequestedBoundaries() throws {
        let cases = [(0,1,0,80,80), (1,1,1,80,79), (79,1,79,80,1),
                     (80,2,0,100,100), (179,2,99,100,1), (180,3,0,125,125)]
        for (xp, level, earned, required, remaining) in cases {
            let progress = try calculator.progress(forTotalXP: xp)
            XCTAssertEqual(progress.level, level)
            XCTAssertEqual(progress.totalXP, xp)
            XCTAssertEqual(progress.xpEarnedWithinCurrentLevel, earned)
            XCTAssertEqual(progress.xpRequiredToNextLevel, required)
            XCTAssertEqual(progress.xpRemainingToNextLevel, remaining)
            XCTAssertEqual(progress.progressFraction, Double(earned) / Double(required), accuracy: 0.0000001)
        }
    }

    func testLargerTotalAndBeyondLevelFiftyAgainstIndependentFixtures() throws {
        // Fixtures independently computed with Python Decimal precision 80, ROUND_HALF_UP.
        for (level, threshold) in [(51,2125), (100,5180), (1000,146050), (10000,5223030)] {
            XCTAssertEqual(try calculator.xpRequiredToAdvance(from: level), threshold)
        }
        let progress = try calculator.progress(forTotalXP: 1_000_000)
        XCTAssertEqual(progress.level, 189)
        XCTAssertEqual(progress.xpEarnedWithinCurrentLevel, 8430)
        XCTAssertEqual(progress.xpRequiredToNextLevel, 12545)
        XCTAssertEqual(progress.xpRemainingToNextLevel, 4115)
    }

    func testNegativeXPClampsToZeroIncludingIntMin() throws {
        let zero = try calculator.progress(forTotalXP: 0)
        for xp in [-1, -1000, Int.min] {
            XCTAssertEqual(try calculator.progress(forTotalXP: xp), zero)
            XCTAssertEqual(try calculator.level(forTotalXP: xp), 1)
        }
    }

    func testAllSupportedThresholdsAreMonotonicAndCumulativeBoundsAreSafe() throws {
        var total = 0
        var previous = 0
        for level in 1...10_000 {
            let required = try calculator.xpRequiredToAdvance(from: level)
            XCTAssertGreaterThan(required, previous)
            XCTAssertEqual(required % 5, 0)
            XCTAssertEqual(try calculator.level(forTotalXP: total), level)
            XCTAssertEqual(try calculator.level(forTotalXP: total + required - 1), level)
            total += required
            previous = required
        }
        XCTAssertEqual(total - 1, 20_320_391_444)
        XCTAssertEqual(calculator.maximumSupportedTotalXP, total - 1)
        let last = try calculator.progress(forTotalXP: total - 1)
        XCTAssertEqual(last.level, 10_000)
        XCTAssertEqual(last.xpRemainingToNextLevel, 1)
    }

    func testInvalidLevelsAndOutOfRangeTotalsThrowInsteadOfOverflowing() {
        for level in [Int.min, -1, 0, 10_001, Int.max] {
            XCTAssertThrowsError(try calculator.xpRequiredToAdvance(from: level)) {
                XCTAssertEqual($0 as? GamificationCalculationError, .invalidLevel(level))
            }
        }
        for total in [calculator.maximumSupportedTotalXP + 1, Int.max] {
            XCTAssertThrowsError(try calculator.progress(forTotalXP: total)) {
                XCTAssertEqual($0 as? GamificationCalculationError, .totalXPOutOfRange(total))
            }
        }
    }

    func testRepeatedCallsAndLowerTotalAreStateless() throws {
        let expected = try calculator.progress(forTotalXP: 1_000_000)
        for _ in 0..<20 {
            XCTAssertEqual(try LevelCalculator().progress(forTotalXP: 1_000_000), expected)
            XCTAssertEqual(try calculator.level(forTotalXP: 79), 1)
        }
    }
}
