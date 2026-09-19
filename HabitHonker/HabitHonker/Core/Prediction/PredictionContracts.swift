//
//  PredictionContracts.swift
//  HabitHonker
//

import Foundation

protocol StateSnapshotBuilding {
    func snapshot(
        for target: BehaviorTarget,
        events: [BehaviorEvent],
        missedDates: [Date],
        asOf date: Date
    ) -> UserStateSnapshot
}

protocol RiskSignalExtracting {
    func riskSignals(from snapshot: UserStateSnapshot) -> [RiskSignal]
}

protocol RiskEvaluating {
    func riskAssessment(
        for snapshot: UserStateSnapshot,
        signals: [RiskSignal],
        asOf date: Date
    ) -> RiskAssessment
}

protocol InterventionSelecting {
    func interventionDecision(
        for assessment: RiskAssessment,
        snapshot: UserStateSnapshot,
        asOf date: Date
    ) -> InterventionDecision
}

protocol DeliveryPolicyEvaluating {
    func deliveryPolicyResult(
        for decision: InterventionDecision,
        snapshot: UserStateSnapshot,
        asOf date: Date
    ) -> DeliveryPolicyResult
}
