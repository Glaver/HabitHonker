/// Immutable, versioned constants. Construction is restricted to supported policies.
struct GamificationPolicy: Sendable {
    static let v1 = GamificationPolicy()
    private init() {}

    let version = 1
    let multiplierScale = 100
    let onTimeMultiplier = 110
    let repeatingBaseXP = 25
    let repeatingBaseCoins = 3
    let oneTimeBaseXP = 40
    let oneTimeBaseCoins = 5
    let minimumRepeatingStreak = 1

    let streakBands: [(minimum: Int, multiplier: Int)] = [
        (1, 100), (2, 105), (4, 110), (7, 115), (14, 120), (30, 125)
    ]
    let streakCoinMilestones = [3: 2, 7: 5, 14: 8, 30: 15, 60: 25, 100: 50]

    func priorityModifiers(for priority: BehaviorPriority) -> (multiplier: Int, coins: Int) {
        switch priority {
        case .importantButNotUrgent: return (130, 2)
        case .importantAndUrgent: return (120, 1)
        case .urgentButNotImportant: return (110, 0)
        case .notUrgentAndNotImportant: return (100, 0)
        }
    }

    let levelBaseXP = 80
    let levelLinearXP = 20
    let levelPowerCoefficient = 2
    let levelExponentNumerator = 8
    let levelExponentDenominator = 5
    let levelRoundingMultiple = 5
    /// Explicit V1 computation range, not a gameplay cap or a truncated 1...50 table.
    let maximumSupportedLevel = 10_000
}
