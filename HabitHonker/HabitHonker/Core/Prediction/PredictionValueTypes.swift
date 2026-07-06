//
//  PredictionValueTypes.swift
//  HabitHonker
//

import Foundation

struct UserStateSnapshot: Equatable, Codable, Sendable {
    var target: BehaviorTarget
    var capturedAt: Date
    var recentCompletionEvents: [BehaviorEvent]
    var recentMissedDates: [Date]

    init(
        target: BehaviorTarget,
        capturedAt: Date,
        recentCompletionEvents: [BehaviorEvent] = [],
        recentMissedDates: [Date] = []
    ) {
        self.target = target
        self.capturedAt = capturedAt
        self.recentCompletionEvents = recentCompletionEvents
        self.recentMissedDates = recentMissedDates
    }
}

struct RiskSignal: Equatable, Codable, Sendable {
    var targetID: BehaviorTargetID
    var kind: RiskSignalKind
    var strength: Double
    var observedAt: Date
    var explanationCode: String

    init(
        targetID: BehaviorTargetID,
        kind: RiskSignalKind,
        strength: Double,
        observedAt: Date,
        explanationCode: String
    ) {
        self.targetID = targetID
        self.kind = kind
        self.strength = strength
        self.observedAt = observedAt
        self.explanationCode = explanationCode
    }
}

enum RiskSignalKind: Equatable, Codable, Sendable {
    case noHistory
    case recentCompletion
    case recentMiss
    case schedulePressure
    case priorityWeight
}

struct RiskAssessment: Equatable, Codable, Sendable {
    var targetID: BehaviorTargetID
    var level: RiskLevel
    var score: Double
    var signals: [RiskSignal]
    var explanationCodes: [String]
    var assessedAt: Date

    init(
        targetID: BehaviorTargetID,
        level: RiskLevel,
        score: Double,
        signals: [RiskSignal] = [],
        explanationCodes: [String] = [],
        assessedAt: Date
    ) {
        self.targetID = targetID
        self.level = level
        self.score = score
        self.signals = signals
        self.explanationCodes = explanationCodes
        self.assessedAt = assessedAt
    }
}

enum RiskLevel: Int, CaseIterable, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

struct Intervention: Equatable, Codable, Sendable {
    var kind: InterventionKind
    var explanationCode: String

    init(kind: InterventionKind, explanationCode: String) {
        self.kind = kind
        self.explanationCode = explanationCode
    }
}

enum InterventionKind: Equatable, Codable, Sendable {
    case none
    case planningPrompt
    case scheduleReview
    case encouragement
}

struct InterventionDecision: Equatable, Codable, Sendable {
    var targetID: BehaviorTargetID
    var riskAssessment: RiskAssessment
    var selectedIntervention: Intervention
    var explanationCodes: [String]
    var decidedAt: Date

    init(
        targetID: BehaviorTargetID,
        riskAssessment: RiskAssessment,
        selectedIntervention: Intervention,
        explanationCodes: [String] = [],
        decidedAt: Date
    ) {
        self.targetID = targetID
        self.riskAssessment = riskAssessment
        self.selectedIntervention = selectedIntervention
        self.explanationCodes = explanationCodes
        self.decidedAt = decidedAt
    }
}

struct DeliveryPolicyResult: Equatable, Codable, Sendable {
    var targetID: BehaviorTargetID
    var isDeliveryAllowed: Bool
    var reasonCodes: [String]
    var evaluatedAt: Date

    init(
        targetID: BehaviorTargetID,
        isDeliveryAllowed: Bool,
        reasonCodes: [String] = [],
        evaluatedAt: Date
    ) {
        self.targetID = targetID
        self.isDeliveryAllowed = isDeliveryAllowed
        self.reasonCodes = reasonCodes
        self.evaluatedAt = evaluatedAt
    }
}
