struct RewardCalculator: RewardCalculating {
    let policy: GamificationPolicy

    init(policy: GamificationPolicy = .v1) {
        self.policy = policy
    }

    func reward(for input: GamificationRewardInput) throws -> GamificationReward {
        guard input.policyVersion == policy.version else {
            throw GamificationCalculationError.unsupportedPolicyVersion(input.policyVersion)
        }
        guard input.streakAfterCompletion >= 0,
              input.taskType != .repeating || input.streakAfterCompletion >= policy.minimumRepeatingStreak else {
            throw GamificationCalculationError.invalidStreak(input.streakAfterCompletion)
        }
        let repeating = input.taskType == .repeating
        let priority = policy.priorityModifiers(for: input.priority)
        let streakMultiplier = repeating
            ? policy.streakBands.last { input.streakAfterCompletion >= $0.minimum }!.multiplier
            : policy.multiplierScale
        let breakdown = RewardCalculationBreakdown(
            baseXP: repeating ? policy.repeatingBaseXP : policy.oneTimeBaseXP,
            baseCoins: repeating ? policy.repeatingBaseCoins : policy.oneTimeBaseCoins,
            multiplierScale: policy.multiplierScale,
            priorityMultiplier: priority.multiplier,
            streakMultiplier: streakMultiplier,
            timingMultiplier: input.isOnTime ? policy.onTimeMultiplier : policy.multiplierScale,
            priorityCoinBonus: priority.coins,
            streakCoinBonus: repeating ? policy.streakCoinMilestones[input.streakAfterCompletion, default: 0] : 0
        )
        // Eligibility gates the whole grant, including priority and milestone coins.
        guard input.rewardEligibility == .eligible else {
            return GamificationReward(xp: 0, honkerCoins: 0, input: input, breakdown: breakdown)
        }
        var numerator = breakdown.baseXP
        var denominator = 1
        for multiplier in [breakdown.priorityMultiplier, breakdown.streakMultiplier, breakdown.timingMultiplier] {
            numerator = try multiply(numerator, multiplier)
            denominator = try multiply(denominator, policy.multiplierScale)
        }
        // One final half-up rounding on a nonnegative rational; no intermediate rounding.
        let xp = try add(numerator, denominator / 2) / denominator
        let coins = try add(try add(breakdown.baseCoins, breakdown.priorityCoinBonus), breakdown.streakCoinBonus)
        return GamificationReward(xp: xp, honkerCoins: coins, input: input, breakdown: breakdown)
    }

    private func multiply(_ a: Int, _ b: Int) throws -> Int {
        let result = a.multipliedReportingOverflow(by: b)
        guard !result.overflow else { throw GamificationCalculationError.arithmeticOverflow }
        return result.partialValue
    }

    private func add(_ a: Int, _ b: Int) throws -> Int {
        let result = a.addingReportingOverflow(b)
        guard !result.overflow else { throw GamificationCalculationError.arithmeticOverflow }
        return result.partialValue
    }
}
