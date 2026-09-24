struct GamificationService: GamificationServiceProtocol {
    private let rewardCalculator: any RewardCalculating
    private let levelCalculator: any LevelCalculating

    init(rewardCalculator: any RewardCalculating, levelCalculator: any LevelCalculating) {
        self.rewardCalculator = rewardCalculator
        self.levelCalculator = levelCalculator
    }

    func reward(for input: GamificationRewardInput) throws -> GamificationReward {
        try rewardCalculator.reward(for: input)
    }

    func levelProgress(forTotalXP totalXP: Int) throws -> LevelProgress {
        try levelCalculator.progress(forTotalXP: totalXP)
    }
}
