import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4E E48–E64: repeat enrollment, the frozen policy, the one clean unenrolled profile row, and
/// every stored state enrollment refuses to guess about. Each refusal asserts that no field of any
/// row changed (`TxStore.state`). Nothing here reconciles, merges, deletes or repairs (that is 4G).
@MainActor
final class GamificationEnrollmentConflictTests: XCTestCase {

    // MARK: E48–E53 — repeat enrollment is idempotent

    func testE48To53RepeatEnrollmentChangesNothing() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        let service = Enroll.service(store)
        let first = try await service.enroll(Enroll.request())
        XCTAssertEqual(first, .enrolled(Enroll.summary(baselines: 5)))
        let afterFirst = try TxStore.state(store)
        let profileID = try Enroll.onlyProfile(store).physicalID
        let baselineIDs = Set(try Enroll.allRows(store).map(\.physicalID))

        // Same request again, then the same policy requested later (§23): the existing boundary wins.
        for request in [Enroll.request(), Enroll.request(at: Sched.at(day: 9, hour: 9)), Enroll.request(at: Sched.at(day: -1, hour: 9))] {
            let again = try await service.enroll(request)
            XCTAssertEqual(again, .alreadyEnrolled(Enroll.summary(baselines: 5)))
            XCTAssertEqual(try TxStore.state(store), afterFirst, "E48/E49: no profile, baseline or other row added")
        }
        XCTAssertEqual(try Enroll.onlyProfile(store).trackingStartedAt, Enroll.at, "E50")
        XCTAssertEqual(try Enroll.onlyProfile(store).physicalID, profileID, "E52")
        XCTAssertEqual(Set(try Enroll.allRows(store).map(\.physicalID)), baselineIDs, "E51")
        XCTAssertEqual(try Enroll.allRows(store).filter { !$0.logicalRevisionID.hasSuffix(":baseline") }, [], "no normal revision")
    }

    func testE53RepeatEnrollmentNeverResetsProgress() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        _ = try await Enroll.service(store).enroll(Enroll.request())
        // Progress recorded after enrollment (as a later reward transaction would record it).
        let context = ModelContext(store)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<GamificationProfileSD>()).first)
        profile.totalXP = 180
        profile.honkerCoins = 12
        profile.lifetimeCoinsEarned = 20
        profile.lifetimeCoinsSpent = 8
        profile.lastProcessedWeekKey = "2027-W02"
        profile.updatedAt = Sched.at(day: 3, hour: 8)
        context.insert(ledgerEntry())
        try context.save()
        let before = try TxStore.state(store)

        let again = try await Enroll.service(store).enroll(Enroll.request(at: Sched.at(day: 4, hour: 9)))
        XCTAssertEqual(again, .alreadyEnrolled(Enroll.summary(baselines: 1)))
        XCTAssertEqual(try TxStore.state(store), before)
        let kept = try Enroll.onlyProfile(store)
        XCTAssertEqual([kept.totalXP, kept.honkerCoins, kept.lifetimeCoinsEarned, kept.lifetimeCoinsSpent], [180, 12, 20, 8])
    }

    // MARK: E54 — the enrollment policy is frozen

    func testE54DifferentPolicyOnASecondCallIsRefusedAndChangesNothing() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        let service = Enroll.service(store)
        _ = try await service.enroll(Enroll.request())
        let existing = Enroll.summary(baselines: 5)
        for zone in ["Asia/Tokyo", "Europe/London", "America/New_York"] {
            try await Enroll.assertRefused(.conflictingExistingEnrollment(existing: existing), store: store) {
                try await service.enroll(Enroll.request(at: Sched.at(day: 9, hour: 9), zone: zone))
            }
        }
        // A non-Gregorian calendar is invalid before the stored policy is even consulted.
        try await Enroll.assertRefused(.unsupportedSchedulingCalendar("buddhist"), store: store) {
            try await service.enroll(Enroll.request(calendar: "buddhist"))
        }
        let profile = try Enroll.onlyProfile(store)
        XCTAssertEqual(profile.trackingStartedAt, Enroll.at)
        XCTAssertEqual(profile.schedulingTimeZoneIdentifier, Sched.la)
        XCTAssertEqual(Set(try Enroll.allRows(store).map(\.payload.timeZone)), [Sched.la])
    }

    func testRepeatEnrollmentNeverAddsBaselinesForHabitsCreatedLater() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let ids = Sched.UUIDSequence()
        let repository = Sched.repository(store, ids: ids)
        _ = try await Enroll.service(repository).enroll(Enroll.request())
        let created = try await repository.createHabit(id: Sched.otherUUID, metadata: Sched.metadata { $0.title = "Later" },
                                                       effectiveAt: Sched.at(day: 1, hour: 10))
        XCTAssertEqual(created.scheduleHistory, .revisionApplied(ScheduleRevisionChange(
            closedRevisionID: nil, openedRevisionID: Sched.changeID(1, target: Sched.otherText), effectiveAt: Sched.at(day: 1, hour: 10))))
        let before = try TxStore.state(store)

        let again = try await Enroll.service(repository).enroll(Enroll.request())
        XCTAssertEqual(again, .alreadyEnrolled(Enroll.summary(baselines: 1)))
        XCTAssertEqual(try TxStore.state(store), before)
        XCTAssertEqual(try Sched.rows(store, target: Sched.otherUUID).map(\.logicalRevisionID), [Sched.changeID(1, target: Sched.otherText)])
    }

    /// A store enrolled with healthy history (baseline closed, normal revision open) is reported,
    /// even when it was not written by this code (the 4B fixtures).
    func testEnrolledStoreWithHealthyRevisionChainIsAlreadyEnrolled() async throws {
        let store = try Sched.enrolledStore(baseline: Sched.RevisionSeed(to: Sched.at(day: 1, hour: 10)))
        try Sched.seedRevision(store, Sched.RevisionSeed(logicalID: Sched.changeID(1), from: Sched.at(day: 1, hour: 10),
                                                         payload: Sched.Payload(priority: 0)))
        try await assertAlreadyEnrolledWithoutWrites(store, baselines: 1)
    }

    // MARK: E55–E56 — one clean unenrolled profile row is initialized in place

    func testE55E56CleanUnenrolledProfileIsInitializedInPlace() async throws {
        let store = try TxStore.memory()
        try Sched.seedProfile(store, trackingStartedAt: nil, timeZone: nil, calendar: nil)
        let physicalID = try Enroll.onlyProfile(store).physicalID
        try Enroll.seedRepresentative(store)

        let result = try await Enroll.service(store).enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 5)))
        let profile = try Enroll.onlyProfile(store)
        XCTAssertEqual(profile.physicalID, physicalID, "E56: the physical row is kept, not replaced")
        Enroll.assertZeroProjection(profile)
        XCTAssertEqual(try Enroll.allRows(store).count, 5)
        try Enroll.assertNoRewardRows(store)
    }

    // MARK: E57–E59 — an unenrolled profile or store with progression evidence is refused

    func testE57E58UnenrolledProfileWithProgressionStateIsRefusedNotZeroed() async throws {
        let dirty: [(String, (GamificationProfileSD) -> Void)] = [
            ("totalXP", { $0.totalXP = 41 }),
            ("honkerCoins", { $0.honkerCoins = 3 }),
            ("lifetimeCoinsEarned", { $0.lifetimeCoinsEarned = 3 }),
            ("lifetimeCoinsSpent", { $0.lifetimeCoinsSpent = 1 }),
            ("negative totalXP", { $0.totalXP = -5 }),
            ("lastProcessedWeekKey", { $0.lastProcessedWeekKey = "2027-W01" }),
            ("aggregateFingerprint", { $0.aggregateFingerprint = "fp:1" }),
        ]
        for (name, change) in dirty {
            let store = try TxStore.memory()
            try Sched.seedHabit(store)
            try insertProfile(store, change)
            try await Enroll.assertRefused(.requiresReconciliation(.nonEmptyUnenrolledProfile), store: store) {
                try await Enroll.service(store).enroll(Enroll.request())
            }
            XCTAssertNil(try Enroll.onlyProfile(store).trackingStartedAt, name)
            XCTAssertEqual(try Enroll.allRows(store), [], name)
        }
    }

    func testUnenrolledProfileWithPartOfAPolicyIsRefused() async throws {
        for (zone, calendar) in [(Sched.la, nil), (nil, Sched.gregorian), (Sched.la, Sched.gregorian)] as [(String?, String?)] {
            let store = try TxStore.memory()
            try Sched.seedProfile(store, trackingStartedAt: nil, timeZone: zone, calendar: calendar)
            try await Enroll.assertRefused(.requiresReconciliation(.incompleteExistingEnrollment), store: store) {
                try await Enroll.service(store).enroll(Enroll.request())
            }
        }
    }

    func testUnenrolledProfileWithAnUnknownPayloadVersionIsRefused() async throws {
        let store = try TxStore.memory()
        try insertProfile(store) { $0.schemaVersion = 2 }
        try await Enroll.assertRefused(.requiresReconciliation(.unsupportedProfileSchemaVersion(2)), store: store) {
            try await Enroll.service(store).enroll(Enroll.request())
        }
    }

    func testE59LedgerWithoutEnrollmentIsRefused() async throws {
        for withProfile in [false, true] {
            let store = try TxStore.memory()
            try Sched.seedHabit(store)
            if withProfile { try Sched.seedProfile(store, trackingStartedAt: nil, timeZone: nil, calendar: nil) }
            let context = ModelContext(store)
            context.insert(ledgerEntry())
            try context.save()
            try await Enroll.assertRefused(.requiresReconciliation(.financialHistoryWithoutEnrollment(ledgerEntryCount: 1)),
                                           store: store) {
                try await Enroll.service(store).enroll(Enroll.request())
            }
            XCTAssertEqual(try Enroll.profiles(store).count, withProfile ? 1 : 0)
        }
    }

    func testOccurrenceOrBehaviorEventWithoutEnrollmentIsRefused() async throws {
        let occurrenceStore = try TxStore.memory()
        let context = ModelContext(occurrenceStore)
        context.insert(TaskOccurrenceSD(logicalOccurrenceID: "occ:v1:\(Sched.targetText):day:2027-01-10", targetID: Sched.targetUUID,
                                        taskTypeRawValue: "repeating", statusRawValue: "completed", provenanceRawValue: "native:v1"))
        try context.save()
        try await Enroll.assertRefused(.requiresReconciliation(.behaviorHistoryWithoutEnrollment(occurrenceCount: 1, eventCount: 0)),
                                       store: occurrenceStore) {
            try await Enroll.service(occurrenceStore).enroll(Enroll.request())
        }

        let eventStore = try TxStore.memory()
        let eventContext = ModelContext(eventStore)
        eventContext.insert(BehaviorEventSD(transitionID: "transition:1", targetID: Sched.targetUUID, timestamp: Sched.at(day: -1, hour: 8),
                                            kindRawValue: "completed", sourceRawValue: "test:v1"))
        try eventContext.save()
        try await Enroll.assertRefused(.requiresReconciliation(.behaviorHistoryWithoutEnrollment(occurrenceCount: 0, eventCount: 1)),
                                       store: eventStore) {
            try await Enroll.service(eventStore).enroll(Enroll.request())
        }
    }

    // MARK: E60, E63 — orphan schedule history is never adopted

    func testE60RevisionsBehindAnUnenrolledProfileAreRefused() async throws {
        let store = try TxStore.memory()
        try Sched.seedProfile(store, trackingStartedAt: nil, timeZone: nil, calendar: nil)
        try Sched.seedHabit(store)
        try Sched.seedRevision(store, Sched.RevisionSeed(logicalID: Sched.changeID(1)))
        try await Enroll.assertRefused(.requiresReconciliation(.scheduleEnrollment(.orphanRevisionHistory)), store: store) {
            try await Enroll.service(store).enroll(Enroll.request())
        }
    }

    func testE63OrphanBaselineRowsWithoutAProfileAreRefused() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        try Sched.seedRevision(store) // the deterministic baseline key, but no profile owns it
        try await Enroll.assertRefused(.requiresReconciliation(.scheduleEnrollment(.orphanRevisionHistory)), store: store) {
            try await Enroll.service(store).enroll(Enroll.request())
        }
        XCTAssertEqual(try Enroll.profiles(store), [], "no profile is created to adopt the rows")
        XCTAssertEqual(try Enroll.allRows(store).count, 1)
    }

    // MARK: E61–E62 — several physical profiles are left to 4G

    func testE61E62SeveralProfileRowsAreRefusedWithoutPickingOne() async throws {
        typealias Row = (tracking: Date?, zone: String?, calendar: String?)
        let enrolled: Row = (Enroll.at, Sched.la, Sched.gregorian)
        let enrolledLater: Row = (Sched.at(day: 0, hour: 9, minute: 4), Sched.la, Sched.gregorian)
        let unenrolled: Row = (nil, nil, nil)
        let cases: [(String, [Row])] = [
            ("two unenrolled", [unenrolled, unenrolled]),
            ("two identical healthy enrollments", [enrolled, enrolled]),
            ("two offline enrollments (Hybrid B+C input)", [enrolled, enrolledLater]),
            ("enrolled + unenrolled", [enrolled, unenrolled]),
            ("three rows", [enrolled, enrolledLater, unenrolled]),
        ]
        for (name, rows) in cases {
            let store = try TxStore.memory()
            try Enroll.seedRepresentative(store)
            for row in rows {
                try Sched.seedProfile(store, trackingStartedAt: row.tracking, timeZone: row.zone, calendar: row.calendar)
            }
            if rows.contains(where: { $0.tracking != nil }) {
                try Sched.seedRevision(store) // a matching baseline, as either device would have written
            }
            try await Enroll.assertRefused(.requiresReconciliation(.scheduleEnrollment(.multipleProfiles(count: rows.count))),
                                           store: store) {
                try await Enroll.service(store).enroll(Enroll.request())
            }
            XCTAssertEqual(try Enroll.profiles(store).count, rows.count, name)
        }
    }

    // MARK: E64 — an inconsistent existing enrollment is reported, never repaired

    func testE64InconsistentExistingEnrollmentIsRefusedAndNotRepaired() async throws {
        let cases: [(String, GamificationEnrollmentConflict, (ModelContainer) throws -> Void)] = [
            ("invalid stored zone", .scheduleEnrollment(.invalidSchedulingTimeZone("Not/AZone")), {
                try Sched.seedProfile($0, timeZone: "Not/AZone")
            }),
            ("missing stored zone", .scheduleEnrollment(.invalidSchedulingTimeZone(nil)), {
                try Sched.seedProfile($0, timeZone: nil)
            }),
            ("non-Gregorian stored calendar", .scheduleEnrollment(.unsupportedSchedulingCalendar("iso8601")), {
                try Sched.seedProfile($0, calendar: "iso8601")
            }),
            ("unknown profile payload version", .unsupportedProfileSchemaVersion(2), { store in
                try self.insertProfile(store) {
                    $0.trackingStartedAt = Enroll.at
                    $0.schedulingTimeZoneIdentifier = Sched.la
                    $0.schedulingCalendarIdentifier = Sched.gregorian
                    $0.schemaVersion = 2
                }
            }),
            ("revision older than the enrollment", .scheduleHistoryPredatesEnrollment(revisionCount: 1), {
                try Sched.seedProfile($0)
                try Sched.seedRevision($0, Sched.RevisionSeed(logicalID: Sched.changeID(1), from: Sched.at(day: -1, hour: 9)))
            }),
            ("baseline not at the enrollment boundary", .baselineBoundaryMismatch(revisionCount: 1), {
                try Sched.seedProfile($0)
                try Sched.seedRevision($0, Sched.RevisionSeed(from: Sched.at(day: 0, hour: 10)))
            }),
        ]
        for (name, conflict, seed) in cases {
            let store = try TxStore.memory()
            try Sched.seedHabit(store)
            try seed(store)
            try await Enroll.assertRefused(.requiresReconciliation(conflict), store: store) {
                try await Enroll.service(store).enroll(Enroll.request())
            }
            XCTAssertEqual(try Enroll.profiles(store).count, 1, name)
        }
    }

    // MARK: - Helpers

    private func assertAlreadyEnrolledWithoutWrites(_ store: ModelContainer, baselines: Int,
                                                    file: StaticString = #filePath, line: UInt = #line) async throws {
        let before = try TxStore.state(store)
        let result = try await Enroll.service(store).enroll(Enroll.request())
        XCTAssertEqual(result, .alreadyEnrolled(Enroll.summary(baselines: baselines)), file: file, line: line)
        XCTAssertEqual(try TxStore.state(store), before, file: file, line: line)
    }

    /// One `profile:v1:default` row, unenrolled and empty unless `change` says otherwise.
    private func insertProfile(_ store: ModelContainer, _ change: (GamificationProfileSD) -> Void) throws {
        let context = ModelContext(store)
        let profile = GamificationProfileSD(logicalProfileKey: Sched.profileKey)
        change(profile)
        context.insert(profile)
        try context.save()
    }

    private func ledgerEntry() -> GamificationLedgerEntrySD {
        GamificationLedgerEntrySD(logicalKey: "grant:1", profileKey: Sched.profileKey, targetID: Sched.targetUUID,
                                  occurrenceID: "occ:v1:\(Sched.targetText):day:2027-01-12", reasonRawValue: "completion",
                                  createdAt: Sched.at(day: 1, hour: 8), policyVersion: 1)
    }
}
