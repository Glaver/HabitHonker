//
//  HabitsRepositorySwiftData+ScheduleHistory.swift
//  HabitHonker
//

import Foundation
import SwiftData

// MARK: - Schedule revision history (Phase 4B)
// Staging only. `stageScheduleHistory` runs inside a Habit mutation of this actor, on that
// mutation's own context, synchronously (no suspension between reading history and the caller's
// save). It reads the profile and the target's revision rows, asks the injected planner, and stages
// at most one closed and one inserted revision. It never saves, never creates or changes a profile,
// and writes no occurrence, event or ledger row. Revision IDs are minted only for rows it inserts.
// When history cannot be extended safely it stages nothing and reports the reason; the Habit
// mutation is saved anyway (v1.1.2 ADR 4.9).
extension HabitsRepositorySwiftData {
    func stageScheduleHistory(_ change: BehaviorScheduleSourceChange,
                              effectiveAt: Date,
                              in ctx: ModelContext) throws -> ScheduleHistoryOutcome {
        let policy: BehaviorSchedulingPolicy
        switch try scheduleEnrollment(in: ctx) {
        case .notEnrolled:
            return .notEnrolled
        case let .unavailable(conflict):
            return .revisionDeferred(conflict)
        case let .enrolled(enrolledPolicy):
            policy = enrolledPolicy
        }

        let rows = try scheduleRevisionRows(targetID: change.targetID, in: ctx)
        let plan = scheduleRevisionPlanner.plan(change.normalized(under: policy),
                                                history: rows.map(BehaviorScheduleRevisionMapper.facts(from:)),
                                                trackingStartedAt: policy.trackingStartedAt,
                                                effectiveAt: effectiveAt)
        switch plan {
        case .noRevisionRequired:
            return .revisionNotRequired

        case let .deferHistory(conflict):
            return .revisionDeferred(conflict)

        case let .replaceOpenRevision(closedRevisionID, at, next):
            let openRows = rows.filter { $0.effectiveTo == nil }
            guard openRows.count == 1 else { return .revisionDeferred(Self.openRowConflict(openRows.count)) }
            openRows[0].effectiveTo = at
            let openedRevisionID = insertOpenRevision(next, effectiveFrom: at, in: ctx)
            return .revisionApplied(ScheduleRevisionChange(closedRevisionID: closedRevisionID,
                                                           openedRevisionID: openedRevisionID,
                                                           effectiveAt: at))

        case let .openRevision(at, next):
            let openedRevisionID = insertOpenRevision(next, effectiveFrom: at, in: ctx)
            return .revisionApplied(ScheduleRevisionChange(closedRevisionID: nil,
                                                           openedRevisionID: openedRevisionID,
                                                           effectiveAt: at))

        case let .closeOpenRevision(closedRevisionID, at):
            let openRows = rows.filter { $0.effectiveTo == nil }
            guard openRows.count == 1 else { return .revisionDeferred(Self.openRowConflict(openRows.count)) }
            openRows[0].effectiveTo = at
            return .revisionApplied(ScheduleRevisionChange(closedRevisionID: closedRevisionID,
                                                           openedRevisionID: nil,
                                                           effectiveAt: at))
        }
    }

    /// Reads (never writes) the V1 logical profile. A store without the V2 gamification models
    /// cannot hold an enrollment, so it is not enrolled.
    private func scheduleEnrollment(in ctx: ModelContext) throws -> BehaviorScheduleEnrollment {
        let schema = ctx.container.schema
        guard schema.entity(for: GamificationProfileSD.self) != nil,
              schema.entity(for: BehaviorScheduleRevisionSD.self) != nil else {
            return .notEnrolled
        }
        let profileKey = BehaviorLogicalIdentity.defaultProfileKey
        let profiles = try ctx.fetch(FetchDescriptor<GamificationProfileSD>(
            predicate: #Predicate<GamificationProfileSD> { $0.logicalProfileKey == profileKey }))
        return try BehaviorScheduleEnrollment.resolve(
            profiles: profiles.map(BehaviorScheduleRevisionMapper.profileFacts(from:)),
            revisionHistoryExists: { try ctx.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()) > 0 })
    }

    /// Every physical revision row of the target, open or closed.
    private func scheduleRevisionRows(targetID: BehaviorTargetID, in ctx: ModelContext) throws -> [BehaviorScheduleRevisionSD] {
        let target = targetID.rawValue
        return try ctx.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>(
            predicate: #Predicate<BehaviorScheduleRevisionSD> { $0.targetID == target }))
    }

    /// Inserts a new open revision with a freshly minted normal revision ID and returns that ID.
    private func insertOpenRevision(_ snapshot: BehaviorScheduleSnapshot,
                                    effectiveFrom: Date,
                                    in ctx: ModelContext) -> String {
        let logicalRevisionID = scheduleRevisionIDs.makeRevisionID(targetID: snapshot.targetID)
        ctx.insert(BehaviorScheduleRevisionMapper.makeOpenRow(logicalRevisionID: logicalRevisionID,
                                                             effectiveFrom: effectiveFrom,
                                                             snapshot: snapshot))
        return logicalRevisionID
    }

    /// Only reachable with a planner that broke its contract: stage nothing, report the rows found.
    private static func openRowConflict(_ openCount: Int) -> BehaviorScheduleHistoryConflict {
        openCount == 0 ? .missingOpenRevision : .multipleOpenRevisions(count: openCount)
    }
}
