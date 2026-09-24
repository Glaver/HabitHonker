protocol LevelCalculating: Sendable {
    func level(forTotalXP totalXP: Int) throws -> Int
    func xpRequiredToAdvance(from level: Int) throws -> Int
    func progress(forTotalXP totalXP: Int) throws -> LevelProgress
}
