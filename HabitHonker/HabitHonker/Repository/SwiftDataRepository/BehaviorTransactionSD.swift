import Foundation
import SwiftData

/// Synchronous helper used only within the repository actor's context operation.
/// Does not own a container/context and does not save or suspend.
struct BehaviorTransactionSD: Sendable {
    let gamificationService: any GamificationServiceProtocol

    func apply(_ command: BehaviorCompletionCommand, in context: ModelContext) throws -> BehaviorTransactionResult {
        try validate(command)
        let commandID = command.commandID
        let transitionID = command.transitionID
        let receipts = try fetch(context, #Predicate<BehaviorEventSD> { $0.commandID == commandID })
        guard receipts.count <= 1 else { throw BehaviorTransactionError.duplicateCommandReceipt(commandID) }
        let transitions = try fetch(context, #Predicate<BehaviorEventSD> { $0.transitionID == transitionID })
        if let existing = receipts.first {
            guard transitions.count == 1, transitions.first?.persistentModelID == existing.persistentModelID,
                  existing.transitionID == transitionID, existing.targetID == command.targetID.rawValue,
                  existing.occurrenceID == command.occurrenceID, existing.timestamp == command.completedAt,
                  existing.sourceRawValue == command.source, existing.predecessorTransitionID == command.predecessorTransitionID,
                  existing.kindRawValue == "completed", existing.schemaVersion == 1,
                  let count = existing.completionCount, count > 0 else {
                throw BehaviorTransactionError.conflictingCommandReceipt(commandID)
            }
            return .duplicateCommand(receipt(command, count: count))
        }
        guard transitions.isEmpty else { throw BehaviorTransactionError.conflictingTransitionID(transitionID) }

        let targetID = command.targetID.rawValue
        let habits = try fetch(context, #Predicate<HabitSD> { $0.id == targetID })
        guard habits.count <= 1 else { throw BehaviorTransactionError.duplicateTarget(command.targetID) }
        guard let habit = habits.first else { throw BehaviorTransactionError.targetNotFound(command.targetID) }
        let profileKey = command.profileKey
        let profiles = try fetch(context, #Predicate<GamificationProfileSD> { $0.logicalProfileKey == profileKey })
        guard profiles.count <= 1 else { throw BehaviorTransactionError.duplicateProfileKey(profileKey) }
        guard let profile = profiles.first else { throw BehaviorTransactionError.profileNotFound(profileKey) }
        guard profile.schemaVersion == 1 else { throw BehaviorTransactionError.inconsistentStoredState("profile version") }

        let occurrenceID = command.occurrenceID
        let occurrences = try fetch(context, #Predicate<TaskOccurrenceSD> { $0.logicalOccurrenceID == occurrenceID })
        guard occurrences.count <= 1 else { throw BehaviorTransactionError.duplicateOccurrenceKey(occurrenceID) }
        let existingOccurrence = occurrences.first
        if let existingOccurrence { try validateSnapshot(existingOccurrence, command) }
        let rewardKey = command.initialRewardKey
        let grants = try fetch(context, #Predicate<GamificationLedgerEntrySD> { $0.logicalKey == rewardKey })
        guard grants.count <= 1 else { throw BehaviorTransactionError.duplicateLedgerLogicalKey(rewardKey) }
        if let grant = grants.first {
            guard existingOccurrence != nil, grant.profileKey == profileKey, grant.targetID == targetID,
                  grant.occurrenceID == occurrenceID, grant.reasonRawValue == "completion", grant.schemaVersion == 1,
                  grant.predecessorLogicalKey == nil else {
                throw BehaviorTransactionError.inconsistentStoredState("initial reward references")
            }
        }

        let records = habit.records ?? []
        let matches = records.filter { $0.date >= command.legacyDay.start && $0.date < command.legacyDay.end }
        guard matches.count <= 1 else { throw BehaviorTransactionError.inconsistentStoredState("multiple legacy records in day") }
        if let existingOccurrence, let recordID = existingOccurrence.legacyRecordID {
            guard records.contains(where: { $0.id == recordID }) else {
                throw BehaviorTransactionError.inconsistentStoredState("missing occurrence legacy projection")
            }
        }
        guard (matches.first?.count ?? 0) >= 0 else { throw BehaviorTransactionError.inconsistentStoredState("negative legacy count") }
        let legacyCount = try add(matches.first?.count ?? 0, 1)
        let occurrenceCount = try add(existingOccurrence?.completionCount ?? 0, 1)

        let disposition: BehaviorRewardDisposition
        let newReward: GamificationReward?
        if grants.first != nil {
            disposition = .alreadyRewarded(logicalKey: rewardKey)
            newReward = nil
        } else if command.rewardInput.rewardEligibility == .ineligible {
            disposition = .ineligible
            newReward = nil
        } else {
            let reward = try gamificationService.reward(for: command.rewardInput)
            guard reward.input == command.rewardInput, reward.xp >= 0, reward.honkerCoins >= 0 else {
                throw BehaviorTransactionError.inconsistentStoredState("invalid reward calculator output")
            }
            disposition = .granted(reward)
            newReward = reward
        }
        let totalXP = try add(profile.totalXP, newReward?.xp ?? 0)
        let coins = try add(profile.honkerCoins, newReward?.honkerCoins ?? 0)
        let earned = try add(profile.lifetimeCoinsEarned, max(newReward?.honkerCoins ?? 0, 0))
        let progress = try gamificationService.levelProgress(forTotalXP: totalXP)

        // All checks/calculation above are read-only. Stage the entire write set below.
        let record: HabitRecordSD
        if let existing = matches.first {
            record = existing
            record.count = legacyCount
        } else {
            record = HabitRecordSD(date: command.legacyCompletionDate, count: legacyCount, habit: habit)
            context.insert(record)
            habit.records = records + [record]
        }
        let occurrence: TaskOccurrenceSD
        if let existingOccurrence {
            occurrence = existingOccurrence
            occurrence.completionCount = occurrenceCount
            if occurrence.completedAt == nil { occurrence.completedAt = command.completedAt }
            occurrence.statusRawValue = "completed"
            if occurrence.legacyRecordID == nil { occurrence.legacyRecordID = record.id }
        } else {
            occurrence = makeOccurrence(command, recordID: record.id)
            context.insert(occurrence)
        }
        context.insert(BehaviorEventSD(transitionID: command.transitionID, commandID: command.commandID,
            targetID: targetID, occurrenceID: occurrenceID, timestamp: command.completedAt,
            kindRawValue: "completed", completionCount: occurrenceCount,
            predecessorTransitionID: command.predecessorTransitionID, sourceRawValue: command.source,
            provenanceRawValue: command.occurrence.provenance))
        if let newReward {
            context.insert(makeLedger(command, reward: newReward))
            profile.totalXP = totalXP
            profile.honkerCoins = coins
            profile.lifetimeCoinsEarned = earned
            profile.updatedAt = command.completedAt
            // A previously computed projection fingerprint no longer describes this balance.
            profile.aggregateFingerprint = nil
        }
        return .applied(BehaviorAppliedCompletion(receipt: receipt(command, count: occurrenceCount),
            legacyRecordID: record.id, legacyCompletionCount: legacyCount, wasExistingOccurrence: existingOccurrence != nil,
            reward: disposition, resultingTotalXP: totalXP, resultingHonkerCoins: coins, resultingLevelProgress: progress))
    }

    private func validate(_ c: BehaviorCompletionCommand) throws {
        guard [c.commandID, c.transitionID, c.profileKey, c.occurrenceID, c.source, c.occurrence.provenance].allSatisfy({ !$0.isEmpty }) else {
            throw BehaviorTransactionError.invalidCommand("empty identity/source/provenance")
        }
        guard c.completedAt.timeIntervalSince1970.isFinite, c.legacyCompletionDate.timeIntervalSince1970.isFinite,
              c.legacyDay.start.timeIntervalSince1970.isFinite, c.legacyDay.end.timeIntervalSince1970.isFinite,
              c.legacyDay.duration > 0, c.legacyCompletionDate >= c.legacyDay.start,
              c.legacyCompletionDate < c.legacyDay.end else {
            throw BehaviorTransactionError.invalidCommand("legacy date must belong to supplied half-open day")
        }
        guard c.occurrence.streakBefore >= 0,
              (c.rewardInput.taskType == .oneTime
                ? c.rewardInput.streakAfterCompletion == 0 && c.occurrence.streakBefore == 0
                : c.rewardInput.streakAfterCompletion >= 1) else {
            throw BehaviorTransactionError.invalidCommand("invalid normalized streak")
        }
    }

    private func validateSnapshot(_ row: TaskOccurrenceSD, _ c: BehaviorCompletionCommand) throws {
        let s = c.occurrence
        let r = c.rewardInput
        guard row.schemaVersion == 1, row.targetID == c.targetID.rawValue,
              row.taskTypeRawValue == r.taskType.rawValue, row.priorityRawValue == r.priority.rawValue,
              row.scheduledLocalDateKey == s.scheduledLocalDateKey, row.scheduledAt == s.scheduledAt,
              row.dueAt == s.dueAt, row.schedulingTimeZoneIdentifier == s.schedulingTimeZoneIdentifier,
              row.schedulingCalendarIdentifier == s.schedulingCalendarIdentifier, row.scheduleRevisionID == s.scheduleRevisionID,
              row.iconName == s.iconName, row.notificationEnabled == s.notificationEnabled,
              row.streakBefore == s.streakBefore, row.streakAfter == r.streakAfterCompletion,
              row.rewardEligibilityRawValue == r.rewardEligibility.rawValue, row.provenanceRawValue == s.provenance,
              row.predecessorOrAliasOccurrenceID == s.predecessorOrAliasOccurrenceID else {
            throw BehaviorTransactionError.conflictingOccurrenceSnapshot(c.occurrenceID)
        }
        guard (row.statusRawValue == "completed" && row.completionCount > 0 && row.completedAt != nil)
                || (row.statusRawValue == "scheduled" && row.completionCount == 0 && row.completedAt == nil) else {
            throw BehaviorTransactionError.inconsistentStoredState("unsupported occurrence state")
        }
    }

    private func makeOccurrence(_ c: BehaviorCompletionCommand, recordID: UUID) -> TaskOccurrenceSD {
        let s = c.occurrence
        return TaskOccurrenceSD(logicalOccurrenceID: c.occurrenceID, targetID: c.targetID.rawValue,
            scheduledLocalDateKey: s.scheduledLocalDateKey, scheduledAt: s.scheduledAt, dueAt: s.dueAt,
            schedulingTimeZoneIdentifier: s.schedulingTimeZoneIdentifier, schedulingCalendarIdentifier: s.schedulingCalendarIdentifier,
            taskTypeRawValue: c.rewardInput.taskType.rawValue, statusRawValue: "completed", completedAt: c.completedAt,
            completionCount: 1, scheduleRevisionID: s.scheduleRevisionID, priorityRawValue: c.rewardInput.priority.rawValue,
            iconName: s.iconName, notificationEnabled: s.notificationEnabled, streakBefore: s.streakBefore,
            streakAfter: c.rewardInput.streakAfterCompletion, rewardEligibilityRawValue: c.rewardInput.rewardEligibility.rawValue,
            legacyRecordID: recordID, provenanceRawValue: s.provenance, predecessorOrAliasOccurrenceID: s.predecessorOrAliasOccurrenceID)
    }

    private func makeLedger(_ c: BehaviorCompletionCommand, reward: GamificationReward) -> GamificationLedgerEntrySD {
        let r = reward.input
        let b = reward.breakdown
        return GamificationLedgerEntrySD(logicalKey: c.initialRewardKey, profileKey: c.profileKey,
            targetID: c.targetID.rawValue, occurrenceID: c.occurrenceID, transitionID: c.transitionID,
            xpDelta: reward.xp, coinDelta: reward.honkerCoins, reasonRawValue: "completion", createdAt: c.completedAt,
            policyVersion: r.policyVersion, taskTypeRawValue: r.taskType.rawValue, priorityRawValue: r.priority.rawValue,
            streakAfterCompletion: r.streakAfterCompletion, isOnTime: r.isOnTime,
            rewardEligibilityRawValue: r.rewardEligibility.rawValue, baseXP: b.baseXP, baseCoins: b.baseCoins,
            multiplierScale: b.multiplierScale, priorityMultiplier: b.priorityMultiplier, streakMultiplier: b.streakMultiplier,
            timingMultiplier: b.timingMultiplier, priorityCoinBonus: b.priorityCoinBonus, streakCoinBonus: b.streakCoinBonus)
    }

    private func receipt(_ c: BehaviorCompletionCommand, count: Int) -> BehaviorCommandReceipt {
        BehaviorCommandReceipt(commandID: c.commandID, transitionID: c.transitionID, targetID: c.targetID,
            occurrenceID: c.occurrenceID, completedAt: c.completedAt, completionCount: count)
    }

    private func fetch<T: PersistentModel>(_ context: ModelContext, _ predicate: Predicate<T>) throws -> [T] {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 2 // Detect ambiguity; never arbitrarily choose among duplicates.
        return try context.fetch(descriptor)
    }

    private func add(_ a: Int, _ b: Int) throws -> Int {
        let (value, overflow) = a.addingReportingOverflow(b)
        guard !overflow else { throw BehaviorTransactionError.arithmeticOverflow }
        return value
    }
}
