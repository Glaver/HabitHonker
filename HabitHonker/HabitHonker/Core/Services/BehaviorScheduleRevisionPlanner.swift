//
//  BehaviorScheduleRevisionPlanner.swift
//  HabitHonker
//

import Foundation

/// V1 schedule-revision planner (Phase 4B). Pure: the result depends only on the arguments.
///
/// Rules, in order:
/// 1. Update/delete of an existing Habit needs exactly one open revision (`effectiveTo == nil`), and
///    its payload must equal the Habit's definition just before the mutation. Otherwise history has
///    already fallen behind, and the mutation must not hide that gap: defer.
/// 2. Update with an unchanged payload: no revision.
/// 3. Create/restore must find no open revision; a second one would never be chosen between later.
/// 4. A boundary written at `effectiveAt` must not predate enrollment, and must not be earlier than
///    any boundary already recorded for the target (no reordering, no overlap).
///    `effectiveAt` equal to the latest boundary is allowed: the closed revision is then `[T, T)`.
/// 5. Several physical open revisions are never resolved by picking one, even identical ones (4G).
struct BehaviorScheduleRevisionPlanner: BehaviorScheduleRevisionPlanning {
    init() {}

    func requiresRevision(current: BehaviorScheduleSnapshot, proposed: BehaviorScheduleSnapshot) -> Bool {
        current != proposed
    }

    func plan(_ mutation: BehaviorScheduleMutation,
              history: [BehaviorScheduleRevisionFacts],
              trackingStartedAt: Date,
              effectiveAt: Date) -> BehaviorScheduleRevisionPlan {
        switch mutation {
        case let .update(current, proposed):
            switch openRevision(in: history, describing: current) {
            case let .unavailable(conflict):
                return .deferHistory(conflict)
            case let .trusted(trusted):
                guard requiresRevision(current: current, proposed: proposed) else {
                    return .noRevisionRequired
                }
                if let conflict = appendConflict(history: history, trackingStartedAt: trackingStartedAt, effectiveAt: effectiveAt) {
                    return .deferHistory(conflict)
                }
                return .replaceOpenRevision(closedRevisionID: trusted.logicalRevisionID, at: effectiveAt, next: proposed)
            }

        case let .delete(current):
            switch openRevision(in: history, describing: current) {
            case let .unavailable(conflict):
                return .deferHistory(conflict)
            case let .trusted(trusted):
                if let conflict = appendConflict(history: history, trackingStartedAt: trackingStartedAt, effectiveAt: effectiveAt) {
                    return .deferHistory(conflict)
                }
                return .closeOpenRevision(closedRevisionID: trusted.logicalRevisionID, at: effectiveAt)
            }

        case let .create(proposed), let .restore(proposed):
            let openCount = history.filter(\.isOpen).count
            guard openCount == 0 else {
                return .deferHistory(openCount == 1 ? .openRevisionAlreadyExists : .multipleOpenRevisions(count: openCount))
            }
            if let conflict = appendConflict(history: history, trackingStartedAt: trackingStartedAt, effectiveAt: effectiveAt) {
                return .deferHistory(conflict)
            }
            return .openRevision(at: effectiveAt, next: proposed)
        }
    }

    // MARK: - Rules

    private enum OpenRevision {
        case trusted(BehaviorScheduleRevisionFacts)
        case unavailable(BehaviorScheduleHistoryConflict)
    }

    /// The single open revision, if it exists and describes `current` exactly.
    private func openRevision(in history: [BehaviorScheduleRevisionFacts],
                              describing current: BehaviorScheduleSnapshot) -> OpenRevision {
        let openRevisions = history.filter(\.isOpen)
        guard openRevisions.count == 1 else {
            return .unavailable(openRevisions.isEmpty ? .missingOpenRevision : .multipleOpenRevisions(count: openRevisions.count))
        }
        guard openRevisions[0].snapshot == current else {
            return .unavailable(.currentRevisionDoesNotMatchCurrentHabit)
        }
        return .trusted(openRevisions[0])
    }

    /// Why a boundary at `effectiveAt` cannot be appended to `history`, if it cannot.
    private func appendConflict(history: [BehaviorScheduleRevisionFacts],
                                trackingStartedAt: Date,
                                effectiveAt: Date) -> BehaviorScheduleHistoryConflict? {
        if effectiveAt < trackingStartedAt {
            return .mutationPredatesEnrollment(trackingStartedAt: trackingStartedAt, effectiveAt: effectiveAt)
        }
        let boundaries = history.flatMap { [$0.effectiveFrom, $0.effectiveTo].compactMap { $0 } }
        if let latest = boundaries.max(), effectiveAt < latest {
            return .revisionChronologyConflict(latestBoundary: latest, effectiveAt: effectiveAt)
        }
        return nil
    }
}
