protocol GamificationServiceProtocol: Sendable {
    func reward(for input: GamificationRewardInput) throws -> GamificationReward
    func levelProgress(forTotalXP totalXP: Int) throws -> LevelProgress
}
