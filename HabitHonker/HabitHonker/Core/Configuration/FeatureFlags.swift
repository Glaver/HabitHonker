//
//  FeatureFlags.swift
//  HabitHonker
//

struct FeatureFlags: Equatable {
    let enableEventLoggingV0: Bool
    let enableBehaviorTargetShadowMapping: Bool
    let enablePredictionCoach: Bool
    let enableRescueCards: Bool
    let enableAppIntents: Bool
    let enableWidgets: Bool
    let enableStabilizationDiagnostics: Bool

    static let defaults = FeatureFlags()

    init(
        enableEventLoggingV0: Bool = false,
        enableBehaviorTargetShadowMapping: Bool = false,
        enablePredictionCoach: Bool = false,
        enableRescueCards: Bool = false,
        enableAppIntents: Bool = false,
        enableWidgets: Bool = false,
        enableStabilizationDiagnostics: Bool = false
    ) {
        self.enableEventLoggingV0 = enableEventLoggingV0
        self.enableBehaviorTargetShadowMapping = enableBehaviorTargetShadowMapping
        self.enablePredictionCoach = enablePredictionCoach
        self.enableRescueCards = enableRescueCards
        self.enableAppIntents = enableAppIntents
        self.enableWidgets = enableWidgets
        self.enableStabilizationDiagnostics = enableStabilizationDiagnostics
    }
}
