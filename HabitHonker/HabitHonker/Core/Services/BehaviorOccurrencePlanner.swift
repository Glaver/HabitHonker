import Foundation

/// Pure action-to-schedule lookup, never a history repair or a completion transaction.
/// The action selects its revision by [from, to). Repeating actions refer only to their local
/// day, never a nearest/previous missed day. Timed obligations must also belong to that revision.
struct BehaviorOccurrencePlanner: BehaviorOccurrencePlanning {
    private let identity = OccurrenceIdentityV1()
    private let days = GregorianLocalDayCalculator()

    func plan(_ input: BehaviorOccurrencePlanningInput) -> BehaviorOccurrencePlan {
        let policy = input.policy
        let rows = input.revisions
        guard input.actionAt.timeIntervalSinceReferenceDate.isFinite,
              policy.trackingStartedAt.timeIntervalSinceReferenceDate.isFinite else {
            return .deferred(.invalidInstant)
        }
        guard input.actionAt >= policy.trackingStartedAt else { return .noOccurrence(.beforeEnrollment) }
        // Validate in category passes, so input ordering cannot change even a conflict result.
        // Empty [T,T) revisions are valid 4B same-instant edits; they own no action.
        guard rows.allSatisfy({ row in
            row.effectiveFrom.timeIntervalSinceReferenceDate.isFinite &&
            (row.effectiveTo.map { $0.timeIntervalSinceReferenceDate.isFinite && $0 >= row.effectiveFrom } ?? true)
        }) else { return .deferred(.invalidInterval) }
        guard rows.allSatisfy({ $0.effectiveFrom >= policy.trackingStartedAt }) else {
            return .deferred(.historyPredatesEnrollment)
        }
        guard Set(rows.map(\.logicalRevisionID)).count == rows.count else {
            return .deferred(.duplicateRevisionIdentity)
        }
        for (index, a) in rows.enumerated() where a.effectiveTo != a.effectiveFrom {
            for b in rows.dropFirst(index + 1) where b.effectiveTo != b.effectiveFrom {
                if (b.effectiveTo.map { a.effectiveFrom < $0 } ?? true) &&
                    (a.effectiveTo.map { b.effectiveFrom < $0 } ?? true) {
                    return .deferred(.overlappingRevisions)
                }
            }
        }
        guard rows.allSatisfy({ $0.snapshot != nil }) else { return .deferred(.undecodableSnapshot) }
        guard rows.allSatisfy({ row in
            guard let snapshot = row.snapshot else { return false }
            return !row.logicalRevisionID.isEmpty && valid(snapshot, target: input.targetID, policy: policy)
        }) else { return .deferred(.invalidSnapshot) }
        let covering = rows.filter { contains(input.actionAt, in: $0) }
        guard covering.count <= 1 else { return .deferred(.overlappingRevisions) }
        if covering.isEmpty {
            // A validated closed lifetime establishes inactivity at its exclusive end and
            // afterwards, until another revision starts. No ordering or current-target facts
            // are needed. Empty history, pre-first history and zero-length-only lifetimes
            // cannot establish a prior active schedule, so remain insufficient evidence.
            let hasPriorLifetime = rows.contains { row in
                guard let end = row.effectiveTo else { return false }
                return row.effectiveFrom < end && end <= input.actionAt
            }
            return hasPriorLifetime ? .noOccurrence(.noActiveRevision) : .deferred(.missingRevision)
        }
        let row = covering[0]
        guard let snapshot = row.snapshot else { return .deferred(.undecodableSnapshot) }
        let dayInstant = snapshot.taskType == .oneTime ? snapshot.dueAt! : input.actionAt
        guard let day = try? days.localDay(containing: dayInstant, timeZoneIdentifier: policy.timeZoneIdentifier) else {
            return .deferred(.unrepresentableLocalDay)
        }
        let scheduledAt: Date?
        let occurrenceID: String
        switch snapshot.taskType {
        case .oneTime:
            scheduledAt = nil
            occurrenceID = identity.oneTimeOccurrenceID(targetID: input.targetID)
        case .repeating:
            let weekday = policy.calendar.component(.weekday, from: day.start)
            guard snapshot.selectedWeekdaysMask & (1 << (weekday - 1)) != 0 else {
                return .noOccurrence(.weekdayNotSelected)
            }
            if let hour = snapshot.scheduledHour, let minute = snapshot.scheduledMinute {
                // Foundation nextTime: a missing spring clock moves to the next valid time
                // (02:30 -> 03:00 in LA). first: a repeated fall clock uses its first instant.
                // Setting on the day includes midnight without epsilon or fixed-day arithmetic.
                guard let instant = policy.calendar.date(bySettingHour: hour, minute: minute, second: 0,
                    of: day.start, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward),
                    day.contains(instant) else { return .deferred(.unrepresentableScheduledTime) }
                scheduledAt = instant
            } else {
                scheduledAt = nil
            }
            occurrenceID = identity.repeatingOccurrenceID(targetID: input.targetID, localDay: day)
        }
        if let candidate = snapshot.dueAt ?? scheduledAt {
            guard candidate >= policy.trackingStartedAt else { return .noOccurrence(.candidateBeforeEnrollment) }
            guard contains(candidate, in: row) else { return .noOccurrence(.candidateOutsideRevision) }
        }
        // Untimed obligations have no fabricated clock. Their day intersects the revision at
        // the eligible action itself, which was checked above (including partial enrollment days).
        return .planned(BehaviorPlannedOccurrence(logicalOccurrenceID: occurrenceID,
            scheduleRevisionID: row.logicalRevisionID, snapshot: snapshot, localDay: day, scheduledAt: scheduledAt))
    }

    private func contains(_ date: Date, in row: BehaviorScheduleRevisionFacts) -> Bool {
        date >= row.effectiveFrom && (row.effectiveTo.map { date < $0 } ?? true)
    }

    private func valid(_ snapshot: BehaviorScheduleSnapshot, target: BehaviorTargetID,
                       policy: BehaviorSchedulingPolicy) -> Bool {
        guard snapshot.targetID == target,
              snapshot.schedulingTimeZoneIdentifier == policy.timeZoneIdentifier,
              snapshot.schedulingCalendarIdentifier == policy.calendarIdentifier else { return false }
        switch snapshot.taskType {
        case .oneTime:
            return snapshot.selectedWeekdaysMask == 0 && snapshot.scheduledHour == nil &&
                snapshot.scheduledMinute == nil && (snapshot.dueAt?.timeIntervalSinceReferenceDate.isFinite == true)
        case .repeating:
            guard (0...127).contains(snapshot.selectedWeekdaysMask), snapshot.dueAt == nil else { return false }
            if snapshot.notificationEnabled {
                guard let hour = snapshot.scheduledHour, let minute = snapshot.scheduledMinute else { return false }
                return (0...23).contains(hour) && (0...59).contains(minute)
            }
            return snapshot.scheduledHour == nil && snapshot.scheduledMinute == nil
        }
    }
}
