import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4E E8–E34, E70, E83–E84 and DST: what a first clean enrollment persists.
/// - The zero-balance `profile:v1:default` with the requested policy.
/// - Exactly one open baseline per current Habit, from one shared `trackingStartedAt`, with the
///   deterministic 4C key and the exact Phase 4B normalized payload.
@MainActor
final class GamificationEnrollmentPersistenceTests: XCTestCase {

    // MARK: E8–E11 — coverage

    func testE8EmptyStoreCreatesTheProfileAndNoBaseline() async throws {
        let store = try TxStore.memory()
        let result = try await Enroll.service(store).enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 0)))
        Enroll.assertZeroProjection(try Enroll.onlyProfile(store))
        XCTAssertEqual(try Enroll.allRows(store), [])
        try Enroll.assertNoRewardRows(store)
    }

    func testE9OneActiveHabitGetsOneBaseline() async throws {
        let store = try TxStore.memory()
        try Sched.seedHabit(store)
        let result = try await Enroll.service(store).enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: 1)))
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, 1)
        let baseline = try Sched.row(rows, "rev:v1:123e4567-e89b-12d3-a456-426614174000:baseline")
        XCTAssertEqual(baseline.effectiveFrom, Enroll.at)
        XCTAssertNil(baseline.effectiveTo)
        XCTAssertEqual(baseline.payload, Sched.Payload(), "the default 4B seed under the Los Angeles policy")
    }

    func testE10ManyActiveHabitsGetExactlyOneBaselineEach() async throws {
        let store = try TxStore.memory()
        let ids = try Enroll.seedHabits(store, count: 12)
        let result = try await Enroll.service(store).enroll(Enroll.request())
        XCTAssertEqual(try Enroll.enrolled(result).baselineRevisionCount, 12)
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, 12)
        XCTAssertEqual(Set(rows.map(\.logicalRevisionID)), Set(ids.map(Enroll.baselineID)))
        XCTAssertEqual(Set(rows.map(\.payload.target)), Set(ids))
        XCTAssertEqual(Set(rows.map(\.physicalID)).count, 12, "one physical row per target")
    }

    func testE11ArchivedHabitsGetNoBaseline() async throws {
        let store = try TxStore.memory()
        let active = try Enroll.seedHabits(store, count: 3)
        let archived = [Enroll.uuid(200), Enroll.uuid(201)]
        for id in archived {
            try Sched.seedArchive(store, Sched.HabitSeed(id: id, title: "Archived"), deletedAt: Sched.at(day: -3, hour: 12))
        }
        let result = try await Enroll.service(store).enroll(Enroll.request())
        XCTAssertEqual(try Enroll.enrolled(result).baselineRevisionCount, 3)
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(Set(rows.map(\.payload.target)), Set(active))
        XCTAssertTrue(Set(rows.map(\.payload.target)).isDisjoint(with: archived))
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<DeletedHabitSD>()), 2, "archives untouched")
    }

    // MARK: E12–E14 — one boundary, open intervals, deterministic identity

    func testE12To14BaselinesShareTheBoundaryAreOpenAndUseTheDeterministicKey() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        let ids = try Enroll.seedHabits(store, count: 6)
        _ = try await Enroll.service(store).enroll(Enroll.request())
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, Enroll.representative.count + ids.count)
        XCTAssertEqual(Set(rows.map(\.effectiveFrom)), [Enroll.at], "E12: one store-wide boundary")
        XCTAssertEqual(rows.filter { $0.effectiveTo != nil }.count, 0, "E13: every baseline is open")
        for row in rows {
            XCTAssertEqual(row.logicalRevisionID, Enroll.baselineID(row.payload.target), "E14")
            XCTAssertEqual(row.logicalRevisionID, "rev:v1:\(row.payload.target.uuidString.lowercased()):baseline")
            XCTAssertNotEqual(row.physicalID, row.payload.target, "the physical row id is not the target id")
            XCTAssertEqual(row.payload.schemaVersion, 1, "existing V1 revision payload version")
        }
        // The frozen 4C example.
        XCTAssertEqual(BehaviorLogicalIdentity.baselineRevisionID(targetID: Sched.target),
                       "rev:v1:123e4567-e89b-12d3-a456-426614174000:baseline")
    }

    // MARK: E15–E23 — the profile is a zero projection with the requested policy

    func testE15To23ProfileIsAZeroProjectionWithTheRequestedPolicy() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        let at = Sched.at(day: 2, hour: 17, minute: 42)
        let result = try await Enroll.service(store).enroll(Enroll.request(at: at, zone: "Europe/London"))
        XCTAssertEqual(result, .enrolled(Enroll.summary(at: at, zone: "Europe/London", baselines: Enroll.representative.count)))
        let profile = try Enroll.onlyProfile(store)
        Enroll.assertZeroProjection(profile, at: at, zone: "Europe/London")
        XCTAssertEqual(profile.logicalProfileKey, BehaviorLogicalIdentity.defaultProfileKey)
        XCTAssertNotEqual(profile.physicalID.uuidString.lowercased(), profile.logicalProfileKey,
                          "the physical row id is not the logical identity")
    }

    // MARK: E24–E34 — exact Phase 4B normalization

    func testE24To34BaselineSnapshotsEqualTheExactPhase4BNormalization() async throws {
        let store = try TxStore.memory()
        try Enroll.seedRepresentative(store)
        _ = try await Enroll.service(store).enroll(Enroll.request())
        let rows = try Enroll.allRows(store)
        XCTAssertEqual(rows.count, Enroll.representative.count)

        // Literal expected payloads (independent of the production normalizer).
        for (seed, expected) in Enroll.representative {
            let row = try Sched.row(rows, Enroll.baselineID(seed.id))
            XCTAssertEqual(row.payload, expected, seed.title)
        }
        let gym = try Sched.row(rows, Enroll.baselineID(Enroll.uuid(1))).payload
        XCTAssertEqual([gym.hour, gym.minute], [7, 30], "E24: repeating reminder clock in the profile zone")
        let laundry = try Sched.row(rows, Enroll.baselineID(Enroll.uuid(2))).payload
        XCTAssertEqual([laundry.hour, laundry.minute], [nil, nil], "E25: reminder off stores no clock")
        XCTAssertEqual(Set(rows.filter { $0.payload.taskType == "repeating" }.map(\.payload.dueAt)), [nil], "E26")
        let taxes = try Sched.row(rows, Enroll.baselineID(Enroll.uuid(3))).payload
        XCTAssertEqual(taxes.mask, 0, "E27: one-time ignores stale weekdays")
        XCTAssertEqual([taxes.hour, taxes.minute], [nil, nil], "E28")
        XCTAssertEqual(taxes.dueAt, Sched.at(day: 3, hour: 17, minute: 15), "E29")
        XCTAssertEqual(rows.map(\.payload.priority).sorted { ($0 ?? -1) < ($1 ?? -1) }, [0, 1, 2, 3, 3], "E30")
        XCTAssertEqual(Set(rows.map(\.payload.icon)), ["atom", "bed", nil, "book", "leaf"], "E31")
        XCTAssertEqual(rows.filter { $0.payload.notification == true }.count, 3, "E32")
        XCTAssertEqual(laundry.mask, 65, "E33: Sunday bit 0 + Saturday bit 6")
        XCTAssertEqual(Set(rows.map(\.payload.timeZone)), [Sched.la], "E34")
        XCTAssertEqual(Set(rows.map(\.payload.calendar)), ["gregorian"], "E34")

        // The stored payload is exactly the 4B normalization of the current Habit row under the
        // enrolled policy (the same rule later normal revisions use).
        let policy = try Enroll.request().schedulingPolicy()
        let context = ModelContext(store)
        for habit in try context.fetch(FetchDescriptor<HabitSD>()) {
            let expected = BehaviorScheduleSnapshot.normalized(BehaviorScheduleRevisionMapper.source(from: habit), policy: policy)
            let baselineKey = Enroll.baselineID(habit.id)
            let stored = try context.fetch(FetchDescriptor<BehaviorScheduleRevisionSD>(
                predicate: #Predicate<BehaviorScheduleRevisionSD> { $0.logicalRevisionID == baselineKey }))
            XCTAssertEqual(stored.count, 1)
            XCTAssertEqual(stored.map(BehaviorScheduleRevisionMapper.snapshot(from:)), [expected], habit.title)
        }
    }

    // MARK: E70 — durable local round trip

    func testE70EnrollmentSurvivesClosingAndReopeningADurableLocalStore() async throws {
        let directory = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("enrollment.store")

        let written = try await enrollOnDisk(url: url)
        let reopened = try XCTUnwrap(PersistentStoreFactory.openStore(for: .local,
                                                                       schema: Schema(versionedSchema: HabitHonkerSchemaV2.self),
                                                                       localStoreURL: url))
        XCTAssertEqual(reopened.durability, .durableLocal)
        XCTAssertEqual(try TxStore.state(reopened.container), written, "every row and field survives reopening")

        let profile = try Enroll.onlyProfile(reopened.container)
        Enroll.assertZeroProjection(profile)
        let rows = try Enroll.allRows(reopened.container)
        for (seed, expected) in Enroll.representative {
            let row = try Sched.row(rows, Enroll.baselineID(seed.id))
            XCTAssertEqual(row.payload, expected, seed.title)
            XCTAssertEqual(row.effectiveFrom, Enroll.at)
            XCTAssertNil(row.effectiveTo)
        }
        try Enroll.assertNoRewardRows(reopened.container)

        // The reopened store is enrolled: a new graph reports it and writes nothing.
        let dependencies = AppDependencies.make(container: reopened.container, storageDurability: reopened.durability)
        let again = try await dependencies.gamificationEnrollmentService.enroll(Enroll.request(at: Sched.at(day: 30, hour: 9)))
        XCTAssertEqual(again, .alreadyEnrolled(Enroll.summary(baselines: Enroll.representative.count)))
        XCTAssertEqual(try TxStore.state(reopened.container), written)
    }

    /// Opens the store the way the app does, enrolls through the production graph, and returns the
    /// complete stored state. The container is released on return.
    private func enrollOnDisk(url: URL) async throws -> [String: [String: AnyHashable?]] {
        let opened = try XCTUnwrap(PersistentStoreFactory.openStore(for: .local,
                                                                     schema: Schema(versionedSchema: HabitHonkerSchemaV2.self),
                                                                     localStoreURL: url))
        XCTAssertEqual(opened.durability, .durableLocal)
        try Enroll.seedRepresentative(opened.container)
        let dependencies = AppDependencies.make(container: opened.container, storageDurability: opened.durability)
        let result = try await dependencies.gamificationEnrollmentService.enroll(Enroll.request())
        XCTAssertEqual(result, .enrolled(Enroll.summary(baselines: Enroll.representative.count)))
        return try TxStore.state(opened.container)
    }

    // MARK: E83–E84 — the device time zone never changes the enrollment

    func testE83E84DeviceTimeZoneDoesNotChangeTheBaselines() async throws {
        let originalCurrent = TimeZone.current.identifier
        var captured: [String: (profile: Enroll.ProfileFacts, rows: [Sched.Row])] = [:]
        var deviceOffsets: [String: Int] = [:]
        for deviceZone in ["Asia/Tokyo", "Europe/London"] {
            try await Enroll.withDeviceTimeZone(deviceZone) {
                deviceOffsets[deviceZone] = TimeZone.current.secondsFromGMT(for: Enroll.at)
                let store = try TxStore.memory()
                try Enroll.seedRepresentative(store)
                _ = try await Enroll.service(store).enroll(Enroll.request())
                captured[deviceZone] = (try Enroll.onlyProfile(store), try Enroll.allRows(store))
            }
        }
        // The two runs really had different device clocks (JST +9 h, GMT +0 in January).
        XCTAssertEqual(deviceOffsets["Asia/Tokyo"], 9 * 3_600)
        XCTAssertEqual(deviceOffsets["Europe/London"], 0)
        XCTAssertEqual(TimeZone.current.identifier, originalCurrent, "the device zone is restored for later tests")

        let tokyo = try XCTUnwrap(captured["Asia/Tokyo"])
        let london = try XCTUnwrap(captured["Europe/London"])
        // Physical row ids differ between the two stores; every semantic field must not.
        XCTAssertEqual(tokyo.rows.map(\.logicalRevisionID), london.rows.map(\.logicalRevisionID))
        XCTAssertEqual(tokyo.rows.map(\.payload), london.rows.map(\.payload))
        XCTAssertEqual(tokyo.rows.map(\.effectiveFrom), london.rows.map(\.effectiveFrom))
        Enroll.assertZeroProjection(tokyo.profile)
        Enroll.assertZeroProjection(london.profile)
        for (seed, expected) in Enroll.representative {
            XCTAssertEqual(try Sched.row(tokyo.rows, Enroll.baselineID(seed.id)).payload, expected, seed.title)
        }
        // 23:05 in Los Angeles (Tokyo would read 16:05 the next day, London 07:05).
        let journal = try Sched.row(tokyo.rows, Enroll.baselineID(Enroll.uuid(5))).payload
        XCTAssertEqual([journal.hour, journal.minute], [23, 5])
    }

    // MARK: §71 — enrollment near DST transitions

    func testEnrollmentNearDSTKeepsTheExactInstantAndReadsClocksInTheProfileZone() async throws {
        let iso = ISO8601DateFormatter()
        // Spring forward in Los Angeles: 2027-03-14 02:00 PST -> 03:00 PDT. Enroll 30 s before.
        let springEnrollment = try XCTUnwrap(iso.date(from: "2027-03-14T09:59:30Z")) // 01:59:30 PST
        let afterJump = try XCTUnwrap(iso.date(from: "2027-03-14T10:30:00Z"))       // 03:30 PDT
        let winterReminder = try XCTUnwrap(iso.date(from: "2027-01-11T15:30:00Z"))  // 07:30 PST
        let oneTimeDue = try XCTUnwrap(iso.date(from: "2027-03-15T07:30:00Z"))      // 00:30 PDT

        let spring = try TxStore.memory()
        try Sched.seedHabit(spring, Sched.HabitSeed(id: Enroll.uuid(1), weekdays: [1], dueDate: afterJump, notification: true))
        try Sched.seedHabit(spring, Sched.HabitSeed(id: Enroll.uuid(2), weekdays: [2], dueDate: winterReminder, notification: true))
        try Sched.seedHabit(spring, Sched.HabitSeed(id: Enroll.uuid(3), type: .dueDate, weekdays: [], dueDate: oneTimeDue,
                                                    notification: true))
        let result = try await Enroll.service(spring).enroll(Enroll.request(at: springEnrollment))
        XCTAssertEqual(try Enroll.enrolled(result).trackingStartedAt, springEnrollment)
        let rows = try Enroll.allRows(spring)
        XCTAssertEqual(Set(rows.map(\.effectiveFrom)), [springEnrollment], "the absolute instant, never shifted by a day")
        XCTAssertEqual(iso.string(from: try XCTUnwrap(Enroll.onlyProfile(spring).trackingStartedAt)), "2027-03-14T09:59:30Z")
        let afterJumpRow = try Sched.row(rows, Enroll.baselineID(Enroll.uuid(1))).payload
        XCTAssertEqual([afterJumpRow.hour, afterJumpRow.minute], [3, 30])
        let winterRow = try Sched.row(rows, Enroll.baselineID(Enroll.uuid(2))).payload
        XCTAssertEqual([winterRow.hour, winterRow.minute], [7, 30], "the wall clock, not a DST-shifted 08:30")
        XCTAssertEqual(try Sched.row(rows, Enroll.baselineID(Enroll.uuid(3))).payload.dueAt, oneTimeDue)

        // Fall back: 2027-11-07 01:30 happens twice. Enroll during the second (PST) 01:30.
        let fallEnrollment = try XCTUnwrap(iso.date(from: "2027-11-07T09:30:00Z"))  // 01:30 PST
        let firstOneThirty = try XCTUnwrap(iso.date(from: "2027-11-07T08:30:00Z"))  // 01:30 PDT
        let fall = try TxStore.memory()
        try Sched.seedHabit(fall, Sched.HabitSeed(id: Enroll.uuid(4), weekdays: [1], dueDate: firstOneThirty, notification: true))
        _ = try await Enroll.service(fall).enroll(Enroll.request(at: fallEnrollment))
        let fallRow = try Sched.row(try Enroll.allRows(fall), Enroll.baselineID(Enroll.uuid(4)))
        XCTAssertEqual(fallRow.effectiveFrom, fallEnrollment)
        XCTAssertEqual([fallRow.payload.hour, fallRow.payload.minute], [1, 30])
        XCTAssertEqual(try Enroll.onlyProfile(fall).trackingStartedAt, fallEnrollment)
    }
}
