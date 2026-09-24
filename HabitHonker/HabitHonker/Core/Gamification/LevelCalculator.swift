struct LevelCalculator: LevelCalculating {
    private let policy = GamificationPolicy.v1

    /// Immutable derived data, computed from the exact curve, not a hand-authored table.
    private static let cumulativeXP: [Int] = {
        let policy = GamificationPolicy.v1
        var result = [0]
        for level in 1...policy.maximumSupportedLevel {
            result.append(result.last! + threshold(level, policy: policy))
        }
        return result
    }()

    /// Largest total representable with a next-level threshold in the supported range.
    var maximumSupportedTotalXP: Int { Self.cumulativeXP.last! - 1 }

    func xpRequiredToAdvance(from level: Int) throws -> Int {
        guard (1...policy.maximumSupportedLevel).contains(level) else {
            throw GamificationCalculationError.invalidLevel(level)
        }
        return Self.threshold(level, policy: policy)
    }

    func level(forTotalXP totalXP: Int) throws -> Int {
        try progress(forTotalXP: totalXP).level
    }

    func progress(forTotalXP totalXP: Int) throws -> LevelProgress {
        let normalizedXP = max(0, totalXP)
        guard normalizedXP <= maximumSupportedTotalXP else {
            throw GamificationCalculationError.totalXPOutOfRange(totalXP)
        }
        let thresholds = Self.cumulativeXP
        var low = 0
        var high = thresholds.count - 1
        while low + 1 < high {
            let middle = low + (high - low) / 2
            if thresholds[middle] <= normalizedXP { low = middle } else { high = middle }
        }
        let earned = normalizedXP - thresholds[low]
        let required = thresholds[low + 1] - thresholds[low]
        return LevelProgress(level: low + 1, totalXP: normalizedXP,
                             xpEarnedWithinCurrentLevel: earned,
                             xpRequiredToNextLevel: required,
                             xpRemainingToNextLevel: required - earned)
    }

    /// V1: A = 80+20n is divisible by 5. Round 2*n^(8/5)/5 to integer k.
    /// k is reached iff (5*(2k-1))^5 <= 4^5*n^8; equality rounds upward.
    /// Binary search compares integers only, avoiding pow/root approximation.
    /// With n<=9999 the RHS is <2^117. Thresholds are <6 million and the
    /// entire cumulative array is <60 billion, safely within 64-bit Int.
    private static func threshold(_ level: Int, policy: GamificationPolicy) -> Int {
        let n = level - 1
        guard n > 0 else { return policy.levelBaseXP }
        var target: UInt128 = 1
        for _ in 0..<policy.levelExponentNumerator { target *= UInt128(n) }
        for _ in 0..<policy.levelExponentDenominator { target *= UInt128(2 * policy.levelPowerCoefficient) }
        var low = 0
        // For V1, 0.4*n^1.6 < n^2 for positive integer n.
        var high = n * n + 1
        while low + 1 < high {
            let middle = low + (high - low) / 2
            let base = UInt128(policy.levelRoundingMultiple * (2 * middle - 1))
            if powerIsAtMost(base, exponent: policy.levelExponentDenominator, limit: target) {
                low = middle
            } else {
                high = middle
            }
        }
        return policy.levelBaseXP + policy.levelLinearXP * n + policy.levelRoundingMultiple * low
    }

    private static func powerIsAtMost(_ base: UInt128, exponent: Int, limit: UInt128) -> Bool {
        var value: UInt128 = 1
        for _ in 0..<exponent {
            // Bound each multiplication before executing it, including large search guesses.
            guard value <= limit / base else { return false }
            value *= base
        }
        return true
    }
}
