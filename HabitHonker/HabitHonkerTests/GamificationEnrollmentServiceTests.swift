import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4E E1–E7: the durability gate, request validation through the Phase 4B policy resolution,
/// and the service boundary. The service reads no clock and no device state.
@MainActor
final class GamificationEnrollmentServiceTests: XCTestCase {

    // MARK: E1–E3 — storage durability gate

    func testE1DurableLocalAllowsEnrollment() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let result = try await Enroll.service(store, durability: .durableLocal).enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 1)))
        Enroll.assertZeroProjection(try Enroll.onlyProfile(store))
        XCTAssertEqual(try Enroll.allRows(store).map(\.logicalRevisionID), [Sched.baselineID])
    }

    /// No CloudKit account or network: the durableCloud classification is what the gate decides on
    /// (the storage classification itself is covered by the Phase 4F tests).
    func testE2DurableCloudIsEligibleToEnroll() async throws {
        XCTAssertTrue(StorageDurabilityState.durableCloud.supportsDurableGamification)
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let result = try await Enroll.service(store, durability: .durableCloud).enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 1)))

        let recording = RecordingEnrollmentRepository(result: .enrolled(Enroll.summary(baselines: 0)))
        _ = try await GamificationEnrollmentService(repository: recording, storageDurability: .durableCloud)
            .enroll(Enroll.request())
        XCTAssertEqual(recording.requests, [Enroll.request()])
    }

    func testE3EphemeralFallbackRejectsEnrollmentWithZeroWrites() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        try await Enroll.assertRefused(.storageNotDurable(.ephemeralFallback), store: store) {
            try await Enroll.service(store, durability: .ephemeralFallback).enroll(Enroll.request())
        }
        XCTAssertEqual(try Enroll.profiles(store), [])
        XCTAssertEqual(try Enroll.allRows(store), [])
        try Enroll.assertNoRewardRows(store)

        // The request never reaches persistence, even when it is also invalid: the gate comes first.
        let recording = RecordingEnrollmentRepository(result: .enrolled(Enroll.summary(baselines: 0)))
        let gated = GamificationEnrollmentService(repository: recording, storageDurability: .ephemeralFallback)
        for request in [Enroll.request(), Enroll.request(zone: "Not/AZone")] {
            do {
                _ = try await gated.enroll(request)
                XCTFail("expected storageNotDurable")
            } catch {
                XCTAssertEqual(error as? GamificationEnrollmentError, .storageNotDurable(.ephemeralFallback))
            }
        }
        XCTAssertEqual(recording.requests, [])
    }

    // MARK: E4–E5 — explicit policy validation, no fallback

    func testE4InvalidTimeZoneIsRejectedWithoutFallback() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        for zone in ["", "Not/AZone", "Mars/Olympus_Mons", "America/Atlantis", " "] {
            try await Enroll.assertRefused(.invalidSchedulingTimeZone(zone), store: store) {
                try await Enroll.service(repository).enroll(Enroll.request(zone: zone))
            }
            // The actor validates again, for callers that bypass the service.
            try await Enroll.assertRefused(.invalidSchedulingTimeZone(zone), store: store) {
                try await repository.enrollGamification(Enroll.request(zone: zone))
            }
        }
        XCTAssertEqual(try Enroll.profiles(store), [])
        XCTAssertEqual(try Enroll.allRows(store), [])
    }

    func testE5UnsupportedCalendarIsRejectedWithoutFallback() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let repository = Sched.repository(store, ids: Sched.UUIDSequence())
        for calendar in ["", "iso8601", "buddhist", "japanese", "Gregorian", "GREGORIAN", "gregorian "] {
            try await Enroll.assertRefused(.unsupportedSchedulingCalendar(calendar), store: store) {
                try await Enroll.service(repository).enroll(Enroll.request(calendar: calendar))
            }
            try await Enroll.assertRefused(.unsupportedSchedulingCalendar(calendar), store: store) {
                try await repository.enrollGamification(Enroll.request(calendar: calendar))
            }
        }
        XCTAssertEqual(try Enroll.profiles(store), [])
    }

    func testRequestDefaultsToTheV1GregorianRepresentation() throws {
        let request = GamificationEnrollmentRequest(enrolledAt: Enroll.at, schedulingTimeZoneIdentifier: Sched.la)
        XCTAssertEqual(request.schedulingCalendarIdentifier, "gregorian")
        XCTAssertEqual(request.schedulingCalendarIdentifier, BehaviorSchedulingPolicy.gregorianCalendarIdentifier)
    }

    /// The request is validated by the same 4B resolution that reads the stored profile afterwards,
    /// so both produce the identical policy.
    func testValidatedRequestPolicyIsTheOneResolvedFromTheStoredProfile() throws {
        for zone in ["America/Los_Angeles", "Asia/Tokyo", "Europe/London", "UTC"] {
            let request = Enroll.request(zone: zone)
            let stored = BehaviorScheduleEnrollment.resolve(
                profiles: [BehaviorScheduleProfileFacts(trackingStartedAt: Enroll.at, schedulingTimeZoneIdentifier: zone,
                                                        schedulingCalendarIdentifier: "gregorian")],
                revisionHistoryExists: { false })
            let policy = try request.schedulingPolicy()
            XCTAssertEqual(stored, .enrolled(policy), zone)
            XCTAssertEqual(policy.timeZoneIdentifier, zone)
            XCTAssertEqual(policy.calendarIdentifier, "gregorian")
            XCTAssertEqual(policy.trackingStartedAt, Enroll.at)
        }
    }

    // MARK: E6 — the caller's instant is persisted exactly

    func testE6RequestTimestampIsPersistedExactly() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        // Sub-second precision, not on a minute boundary.
        let instant = Date(timeIntervalSinceReferenceDate: 811_234_567.125)
        let result = try await Enroll.service(store).enroll(Enroll.request(at: instant))
        XCTAssertEqual(try Enroll.enrolled(result).trackingStartedAt, instant)
        let profile = try Enroll.onlyProfile(store)
        XCTAssertEqual(profile.trackingStartedAt, instant)
        XCTAssertEqual(profile.updatedAt, instant)
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, Enroll.representative.count)
        XCTAssertEqual(Set(rows.map(\.effectiveFrom)), [instant])
    }

    // MARK: E7 — no device dependency at the service boundary

    func testE7ServiceForwardsTheExplicitRequestUnchangedAndReturnsTheRepositoryResult() async throws {
        let expected = GamificationEnrollmentResult.alreadyEnrolled(Enroll.summary(zone: "Asia/Tokyo", baselines: 7))
        let recording = RecordingEnrollmentRepository(result: expected)
        let service = GamificationEnrollmentService(repository: recording, storageDurability: .durableLocal)
        // A zone that is neither this test process's zone nor UTC.
        let request = Enroll.request(at: Sched.at(day: 4, hour: 21, minute: 13), zone: "Pacific/Chatham")
        let result = try await service.enroll(request)
        XCTAssertEqual(result, expected)
        XCTAssertEqual(recording.requests, [request], "forwarded exactly once and unchanged")

        // An invalid request never reaches the repository.
        do {
            _ = try await service.enroll(Enroll.request(zone: "Nowhere/Special"))
            XCTFail("expected invalidSchedulingTimeZone")
        } catch {
            XCTAssertEqual(error as? GamificationEnrollmentError, .invalidSchedulingTimeZone("Nowhere/Special"))
        }
        XCTAssertEqual(recording.requests, [request])
    }

    func testV1OnlyStoreCannotHoldAnEnrollment() async throws {
        let schema = Schema(versionedSchema: HabitHonkerSchemaV1.self)
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                                                                        cloudKitDatabase: .none))
        let context = ModelContext(store)
        context.insert(HabitSD(id: Sched.targetUUID, title: "Legacy"))
        try context.save()
        do {
            _ = try await Enroll.service(store).enroll(Enroll.request())
            XCTFail("expected gamificationStorageUnavailable")
        } catch {
            XCTAssertEqual(error as? GamificationEnrollmentError, .gamificationStorageUnavailable)
        }
        XCTAssertEqual(try ModelContext(store).fetch(FetchDescriptor<HabitSD>()).map(\.title), ["Legacy"])
    }
}
