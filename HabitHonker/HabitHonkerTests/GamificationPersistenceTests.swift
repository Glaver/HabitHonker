import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

@MainActor
final class GamificationPersistenceTests: XCTestCase {
    func testOccurrenceAllScalarsAndUnknownMetadataRoundTrip() throws {
        try roundTrip(id: \TaskOccurrenceSD.id, snapshot: occurrenceSnapshot) {
            [TaskOccurrenceSD(id: Phase2TestStore.id(101), logicalOccurrenceID: "occ:v1:task:day:2026-09-23",
                targetID: Phase2TestStore.id(1), scheduledLocalDateKey: "2026-09-23", scheduledAt: Phase2TestStore.date(1),
                dueAt: Phase2TestStore.date(2), schedulingTimeZoneIdentifier: "America/Los_Angeles",
                schedulingCalendarIdentifier: "gregorian", taskTypeRawValue: GamificationTaskType.repeating.rawValue,
                statusRawValue: "completed", completedAt: Phase2TestStore.date(3), completionCount: 2,
                scheduleRevisionID: "revision:v1:1", priorityRawValue: BehaviorPriority.importantButNotUrgent.rawValue,
                iconName: "biceps-flexed", notificationEnabled: true, streakBefore: 6, streakAfter: 7,
                rewardEligibilityRawValue: RewardEligibility.eligible.rawValue, legacyRecordID: Phase2TestStore.id(11),
                provenanceRawValue: "native:v1", predecessorOrAliasOccurrenceID: "occ:v1:previous", schemaVersion: 1),
             TaskOccurrenceSD(id: Phase2TestStore.id(102), logicalOccurrenceID: "occ:v1:unknown:once",
                targetID: Phase2TestStore.id(2), taskTypeRawValue: GamificationTaskType.oneTime.rawValue,
                statusRawValue: "unknown", provenanceRawValue: "legacyUnknown:v1")]
        }
    }

    func testScheduleRevisionAllScalarsAndOptionalDatesRoundTrip() throws {
        try roundTrip(id: \BehaviorScheduleRevisionSD.id, snapshot: revisionSnapshot) {
            [BehaviorScheduleRevisionSD(id: Phase2TestStore.id(201), logicalRevisionID: "revision:v1:1",
                targetID: Phase2TestStore.id(1), effectiveFrom: Phase2TestStore.date(1), effectiveTo: Phase2TestStore.date(2),
                taskTypeRawValue: GamificationTaskType.repeating.rawValue, selectedWeekdaysMask: 42,
                scheduledHour: 9, scheduledMinute: 30, dueAt: Phase2TestStore.date(3),
                schedulingTimeZoneIdentifier: "America/Los_Angeles", schedulingCalendarIdentifier: "gregorian",
                priorityRawValue: BehaviorPriority.importantButNotUrgent.rawValue, iconName: "bed", notificationEnabled: false),
             BehaviorScheduleRevisionSD(id: Phase2TestStore.id(202), logicalRevisionID: "revision:v1:2",
                targetID: Phase2TestStore.id(2), effectiveFrom: Phase2TestStore.date(4), taskTypeRawValue: "oneTime")]
        }
        let weekdays = BehaviorWeekday.allCases.filter { 42 & (1 << ($0.rawValue - 1)) != 0 }
        XCTAssertEqual(weekdays, [.monday, .wednesday, .friday])
    }

    func testEventScalarsPreserveExistingKindVocabularyAndCountPayload() throws {
        try roundTrip(id: \BehaviorEventSD.id, snapshot: eventSnapshot) {
            [BehaviorEventSD(id: Phase2TestStore.id(301), transitionID: "transition:v1:1", commandID: "command:v1:1",
                targetID: Phase2TestStore.id(1), occurrenceID: "occ:v1:1:once", timestamp: Phase2TestStore.date(1),
                kindRawValue: "completed", completionCount: 3, predecessorTransitionID: "transition:v1:0",
                sourceRawValue: "user:v1", provenanceRawValue: "native:v1"),
             BehaviorEventSD(id: Phase2TestStore.id(302), transitionID: "transition:v1:2", targetID: Phase2TestStore.id(2),
                timestamp: Phase2TestStore.date(2), kindRawValue: "archived", sourceRawValue: "import:v1"),
             BehaviorEventSD(id: Phase2TestStore.id(303), transitionID: "transition:v1:3", targetID: Phase2TestStore.id(2),
                timestamp: Phase2TestStore.date(3), kindRawValue: "deleted", sourceRawValue: "user:v1")]
        }
    }

    func testProfileAllScalarsAndUnenrolledDefaultsRoundTrip() throws {
        try roundTrip(id: \GamificationProfileSD.id, snapshot: profileSnapshot) {
            [GamificationProfileSD(id: Phase2TestStore.id(401), logicalProfileKey: "profile:v1:default", totalXP: 180,
                honkerCoins: 7, lifetimeCoinsEarned: 12, lifetimeCoinsSpent: 5, trackingStartedAt: Phase2TestStore.date(1),
                schedulingTimeZoneIdentifier: "America/Los_Angeles", schedulingCalendarIdentifier: "gregorian",
                lastProcessedWeekKey: "week:v1:2026-09-21", aggregateFingerprint: "fixture-fingerprint",
                updatedAt: Phase2TestStore.date(2)),
             GamificationProfileSD(id: Phase2TestStore.id(402), logicalProfileKey: "profile:v1:unenrolled")]
        }
        let unenrolled = GamificationProfileSD(logicalProfileKey: "profile:v1:fixture")
        XCTAssertNil(unenrolled.trackingStartedAt)
        XCTAssertNil(unenrolled.updatedAt)
        XCTAssertEqual(unenrolled.totalXP, 0)
        XCTAssertEqual(unenrolled.honkerCoins, 0)
    }

    func testLedgerFrozenGrantAndLinkedCompensationRoundTripWithoutRecalculation() throws {
        try roundTrip(id: \GamificationLedgerEntrySD.id, snapshot: ledgerSnapshot) {
            [self.grant(id: Phase2TestStore.id(501)),
             GamificationLedgerEntrySD(id: Phase2TestStore.id(502), logicalKey: "reverse:grant:1",
                profileKey: "profile:v1:default", targetID: Phase2TestStore.id(1), occurrenceID: "occ:v1:1:day:2026-09-23",
                xpDelta: -41, coinDelta: -10, reasonRawValue: "reversal",
                predecessorLogicalKey: "grant:1", createdAt: Phase2TestStore.date(2), policyVersion: 1)]
        }
        let row = grant(id: Phase2TestStore.id(503))
        // Exact supplied audit facts; persistence never invokes the calculator.
        XCTAssertEqual(row.xpDelta, 41)
        XCTAssertEqual(row.coinDelta, 10)
        XCTAssertEqual(row.taskTypeRawValue, GamificationTaskType.repeating.rawValue)
        XCTAssertEqual(row.priorityRawValue, BehaviorPriority.importantButNotUrgent.rawValue)
        XCTAssertEqual(row.streakAfterCompletion, 7)
        XCTAssertEqual(row.isOnTime, true)
        XCTAssertEqual(row.rewardEligibilityRawValue, RewardEligibility.eligible.rawValue)
    }

    func testHistoryCanExistWithoutHabitAndSurvivesHabitDeletion() throws {
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("history.store")
        try autoreleasepool {
            let container = try Phase2TestStore.container(url: url)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            context.insert(grant(id: Phase2TestStore.id(501)))
            context.insert(TaskOccurrenceSD(logicalOccurrenceID: "occ:v1:1:once", targetID: Phase2TestStore.id(1),
                taskTypeRawValue: "oneTime", statusRawValue: "completed", provenanceRawValue: "native:v1"))
            try context.save()
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitSD>()), 0)
            let habit = HabitSD(id: Phase2TestStore.id(1), title: "Temporary habit")
            context.insert(habit)
            try context.save()
            context.delete(habit)
            try context.save()
        }
        try autoreleasepool {
            let context = ModelContext(try Phase2TestStore.container(url: url))
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitSD>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskOccurrenceSD>()), 1)
            let ledger = try XCTUnwrap(context.fetch(FetchDescriptor<GamificationLedgerEntrySD>()).first)
            XCTAssertEqual(ledgerSnapshot(ledger), ledgerSnapshot(grant(id: Phase2TestStore.id(501))))
        }
    }

    func testDuplicateLogicalKeysDoNotUpsertOrMergePhysicalRows() throws {
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("duplicates.store")
        try autoreleasepool {
            let context = ModelContext(try Phase2TestStore.container(url: url))
            context.autosaveEnabled = false
            for n in 1...2 {
                context.insert(GamificationProfileSD(id: Phase2TestStore.id(n), logicalProfileKey: "profile:v1:default"))
                context.insert(grant(id: Phase2TestStore.id(500 + n)))
                context.insert(TaskOccurrenceSD(logicalOccurrenceID: "same-occurrence", targetID: Phase2TestStore.id(1),
                    taskTypeRawValue: "oneTime", statusRawValue: "unknown", provenanceRawValue: "native:v1"))
                context.insert(BehaviorScheduleRevisionSD(logicalRevisionID: "same-revision", targetID: Phase2TestStore.id(1),
                    effectiveFrom: Phase2TestStore.date(1), taskTypeRawValue: "oneTime"))
                context.insert(BehaviorEventSD(transitionID: "same-transition", targetID: Phase2TestStore.id(1),
                    timestamp: Phase2TestStore.date(1), kindRawValue: "completed", completionCount: 1, sourceRawValue: "user:v1"))
            }
            try context.save()
        }
        try autoreleasepool {
            let context = ModelContext(try Phase2TestStore.container(url: url))
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<GamificationProfileSD>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskOccurrenceSD>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorEventSD>()), 2)
        }
    }

    func testLiveCompletionInV2LeavesAllNewTablesEmpty() async throws {
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let container = try Phase2TestStore.container(url: dir.appendingPathComponent("completion.store"))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let habit = HabitSD(id: Phase2TestStore.id(1), title: "Ordinary habit")
        context.insert(habit)
        try context.save()
        let service = HabitService(repository: SwiftDataHabitRepository(container: container), habitEvents: HabitEventCenter())
        let first = try await service.completeHabit(id: habit.id)
        XCTAssertEqual(first?.record.reduce(0) { $0 + $1.count }, 1)
        let second = try await service.completeHabit(id: habit.id)
        XCTAssertEqual(second?.record.reduce(0) { $0 + $1.count }, 2)
        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<HabitSD>()).first?.records?.reduce(0) { $0 + $1.count }, 2)
        try Phase2TestStore.assertNewTablesEmpty(fresh)
    }

    func testSourceBoundariesKeepStorageOutOfLiveCompletion() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("HabitHonker")
        for path in ["Core/Services/HabitService.swift", "Screens/TaskList/HabitListViewModel.swift", "Screens/TaskList/HabitModel.swift",
                     "App/AppDependencies.swift", "Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            for forbidden in ["GamificationService", "GamificationProfileSD", "GamificationLedgerEntrySD", "TaskOccurrenceSD", "BehaviorEventSD", "BehaviorScheduleRevisionSD"] {
                XCTAssertFalse(source.contains(forbidden), "\(path): \(forbidden)")
            }
        }
        for name in ["BehaviorSD.swift", "GamificationSD.swift", "HabitSchemaMigration.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent("Repository/SwiftDataRepository/\(name)"), encoding: .utf8)
            for forbidden in ["@Attribute(.unique)", "import SwiftUI", "NotificationCenter", "HabitEventCenter", "Date()", "RewardCalculator", "GamificationService", "Hasher", "deleteRule: .cascade"] {
                XCTAssertFalse(source.contains(forbidden), "\(name): \(forbidden)")
            }
        }
    }

    private func grant(id: UUID) -> GamificationLedgerEntrySD {
        GamificationLedgerEntrySD(id: id, logicalKey: "grant:1", profileKey: "profile:v1:default", targetID: Phase2TestStore.id(1),
            occurrenceID: "occ:v1:1:day:2026-09-23", transitionID: "transition:v1:1", xpDelta: 41, coinDelta: 10,
            reasonRawValue: "completion", createdAt: Phase2TestStore.date(1), policyVersion: 1,
            taskTypeRawValue: GamificationTaskType.repeating.rawValue, priorityRawValue: BehaviorPriority.importantButNotUrgent.rawValue,
            streakAfterCompletion: 7, isOnTime: true, rewardEligibilityRawValue: RewardEligibility.eligible.rawValue,
            baseXP: 25, baseCoins: 3, multiplierScale: 100, priorityMultiplier: 130, streakMultiplier: 115,
            timingMultiplier: 110, priorityCoinBonus: 2, streakCoinBonus: 5)
    }

    private func roundTrip<T: PersistentModel>(id: KeyPath<T, UUID>, snapshot: (T) -> [String: AnyHashable?],
                                                make: () -> [T]) throws {
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("roundtrip.store")
        let expected = try autoreleasepool {
            let context = ModelContext(try Phase2TestStore.container(url: url))
            context.autosaveEnabled = false
            let rows = make()
            let entity = try XCTUnwrap(Schema(versionedSchema: HabitHonkerSchemaV2.self).entity(for: T.self))
            for row in rows {
                XCTAssertEqual(Set(snapshot(row).keys), Set(entity.attributes.map(\.name)), "Every stored scalar must be asserted")
                context.insert(row)
            }
            try context.save()
            return Dictionary(uniqueKeysWithValues: rows.map { ($0[keyPath: id], snapshot($0)) })
        }
        try autoreleasepool {
            let context = ModelContext(try Phase2TestStore.container(url: url))
            let rows = try context.fetch(FetchDescriptor<T>())
            XCTAssertEqual(Dictionary(uniqueKeysWithValues: rows.map { ($0[keyPath: id], snapshot($0)) }), expected)
        }
    }

    private func occurrenceSnapshot(_ row: TaskOccurrenceSD) -> [String: AnyHashable?] {
        [
            "id": row.id,
            "logicalOccurrenceID": row.logicalOccurrenceID,
            "targetID": row.targetID,
            "scheduledLocalDateKey": row.scheduledLocalDateKey,
            "scheduledAt": row.scheduledAt,
            "dueAt": row.dueAt,
            "schedulingTimeZoneIdentifier": row.schedulingTimeZoneIdentifier,
            "schedulingCalendarIdentifier": row.schedulingCalendarIdentifier,
            "taskTypeRawValue": row.taskTypeRawValue,
            "statusRawValue": row.statusRawValue,
            "completedAt": row.completedAt,
            "completionCount": row.completionCount,
            "scheduleRevisionID": row.scheduleRevisionID,
            "priorityRawValue": row.priorityRawValue,
            "iconName": row.iconName,
            "notificationEnabled": row.notificationEnabled,
            "streakBefore": row.streakBefore,
            "streakAfter": row.streakAfter,
            "rewardEligibilityRawValue": row.rewardEligibilityRawValue,
            "legacyRecordID": row.legacyRecordID,
            "provenanceRawValue": row.provenanceRawValue,
            "predecessorOrAliasOccurrenceID": row.predecessorOrAliasOccurrenceID,
            "schemaVersion": row.schemaVersion
        ]
    }

    private func revisionSnapshot(_ row: BehaviorScheduleRevisionSD) -> [String: AnyHashable?] {
        [
            "id": row.id,
            "logicalRevisionID": row.logicalRevisionID,
            "targetID": row.targetID,
            "effectiveFrom": row.effectiveFrom,
            "effectiveTo": row.effectiveTo,
            "taskTypeRawValue": row.taskTypeRawValue,
            "selectedWeekdaysMask": row.selectedWeekdaysMask,
            "scheduledHour": row.scheduledHour,
            "scheduledMinute": row.scheduledMinute,
            "dueAt": row.dueAt,
            "schedulingTimeZoneIdentifier": row.schedulingTimeZoneIdentifier,
            "schedulingCalendarIdentifier": row.schedulingCalendarIdentifier,
            "priorityRawValue": row.priorityRawValue,
            "iconName": row.iconName,
            "notificationEnabled": row.notificationEnabled,
            "schemaVersion": row.schemaVersion
        ]
    }

    private func eventSnapshot(_ row: BehaviorEventSD) -> [String: AnyHashable?] {
        [
            "id": row.id,
            "transitionID": row.transitionID,
            "commandID": row.commandID,
            "targetID": row.targetID,
            "occurrenceID": row.occurrenceID,
            "timestamp": row.timestamp,
            "kindRawValue": row.kindRawValue,
            "completionCount": row.completionCount,
            "predecessorTransitionID": row.predecessorTransitionID,
            "sourceRawValue": row.sourceRawValue,
            "provenanceRawValue": row.provenanceRawValue,
            "schemaVersion": row.schemaVersion
        ]
    }

    private func profileSnapshot(_ row: GamificationProfileSD) -> [String: AnyHashable?] {
        [
            "id": row.id,
            "logicalProfileKey": row.logicalProfileKey,
            "totalXP": row.totalXP,
            "honkerCoins": row.honkerCoins,
            "lifetimeCoinsEarned": row.lifetimeCoinsEarned,
            "lifetimeCoinsSpent": row.lifetimeCoinsSpent,
            "trackingStartedAt": row.trackingStartedAt,
            "schedulingTimeZoneIdentifier": row.schedulingTimeZoneIdentifier,
            "schedulingCalendarIdentifier": row.schedulingCalendarIdentifier,
            "lastProcessedWeekKey": row.lastProcessedWeekKey,
            "aggregateFingerprint": row.aggregateFingerprint,
            "schemaVersion": row.schemaVersion,
            "updatedAt": row.updatedAt
        ]
    }

    private func ledgerSnapshot(_ row: GamificationLedgerEntrySD) -> [String: AnyHashable?] {
        [
            "id": row.id,
            "logicalKey": row.logicalKey,
            "profileKey": row.profileKey,
            "targetID": row.targetID,
            "occurrenceID": row.occurrenceID,
            "transitionID": row.transitionID,
            "xpDelta": row.xpDelta,
            "coinDelta": row.coinDelta,
            "reasonRawValue": row.reasonRawValue,
            "predecessorLogicalKey": row.predecessorLogicalKey,
            "createdAt": row.createdAt,
            "schemaVersion": row.schemaVersion,
            "policyVersion": row.policyVersion,
            "taskTypeRawValue": row.taskTypeRawValue,
            "priorityRawValue": row.priorityRawValue,
            "streakAfterCompletion": row.streakAfterCompletion,
            "isOnTime": row.isOnTime,
            "rewardEligibilityRawValue": row.rewardEligibilityRawValue,
            "baseXP": row.baseXP,
            "baseCoins": row.baseCoins,
            "multiplierScale": row.multiplierScale,
            "priorityMultiplier": row.priorityMultiplier,
            "streakMultiplier": row.streakMultiplier,
            "timingMultiplier": row.timingMultiplier,
            "priorityCoinBonus": row.priorityCoinBonus,
            "streakCoinBonus": row.streakCoinBonus
        ]
    }
}
