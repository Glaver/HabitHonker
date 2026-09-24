protocol RewardCalculating: Sendable {
    func reward(for input: GamificationRewardInput) throws -> GamificationReward
}
