import Foundation

/// All physical revisions for exactly one target, including undecodable rows. The caller must
/// scope the history by target before mapping it: 4B facts with nil snapshots have no target ID.
struct BehaviorOccurrencePlanningInput: Equatable, Sendable {
    let targetID: BehaviorTargetID
    let policy: BehaviorSchedulingPolicy
    let revisions: [BehaviorScheduleRevisionFacts]
    let actionAt: Date
}

/// Scheduling facts only. The transaction snapshot additionally requires streak and provenance;
/// those cannot be inferred here. No completion state or reward eligibility is fabricated.
struct BehaviorPlannedOccurrence: Equatable, Sendable {
    let logicalOccurrenceID: String
    let scheduleRevisionID: String
    let snapshot: BehaviorScheduleSnapshot
    /// Repeating: action's local day. One-time: authoritative due instant's local day.
    let localDay: LocalDay
    let scheduledAt: Date?
    var targetID: BehaviorTargetID { snapshot.targetID }
    var taskType: GamificationTaskType { snapshot.taskType }
    var dueAt: Date? { snapshot.dueAt }
}

enum BehaviorOccurrencePlan: Equatable, Sendable {
    case planned(BehaviorPlannedOccurrence)
    case noOccurrence(BehaviorOccurrenceAbsence)
    case deferred(BehaviorOccurrencePlanningConflict)
}

enum BehaviorOccurrenceAbsence: Equatable, Sendable {
    case beforeEnrollment
    /// Validated history contains a prior nonempty closed revision, but none active now.
    case noActiveRevision
    case weekdayNotSelected
    case candidateBeforeEnrollment
    case candidateOutsideRevision
}

enum BehaviorOccurrencePlanningConflict: Equatable, Sendable {
    case invalidInstant
    case invalidInterval
    case historyPredatesEnrollment
    case duplicateRevisionIdentity
    case overlappingRevisions
    case undecodableSnapshot
    case invalidSnapshot
    case missingRevision
    case unrepresentableLocalDay
    case unrepresentableScheduledTime
}
