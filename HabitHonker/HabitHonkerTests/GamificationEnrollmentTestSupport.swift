import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4E fixtures, built on the 4B `Sched` and Phase 3 `TxStore` helpers.
///
/// - Enrollment goes through the production service, adapter and actor.
/// - Expected baseline payloads are literal values, independent of the production normalizer.
/// - Expected baseline IDs are literal strings, independent of the 4C identity helper.
/// - Every instant is a Los Angeles wall-clock time built on an explicit Gregorian calendar.
@MainActor
enum Enroll {
    /// Enrollment instant: Monday 2027-01-11 09:00 Los Angeles (the 4B fixture enrollment).
    static let at = Sched.trackingStartedAt

    static func request(at: Date = Enroll.at,
                        zone: String = Sched.la,
                        calendar: String = Sched.gregorian) -> GamificationEnrollmentRequest {
        GamificationEnrollmentRequest(enrolledAt: at, schedulingTimeZoneIdentifier: zone, schedulingCalendarIdentifier: calendar)
    }

    /// `E0000000-0000-4000-8000-00000000000n`
    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "E0000000-0000-4000-8000-%012d", n))!
    }

    /// The frozen 4C baseline key, written out literally.
    static func baselineID(_ target: UUID) -> String {
        "rev:v1:\(target.uuidString.lowercased()):baseline"
    }

    /// The production service over the production adapter and the given (shared) actor.
    static func service(_ repository: HabitsRepositorySwiftData,
                        durability: StorageDurabilityState = .durableLocal) -> GamificationEnrollmentService {
        GamificationEnrollmentService(repository: SwiftDataGamificationEnrollmentRepository(repository: repository),
                                      storageDurability: durability)
    }

    static func service(_ store: ModelContainer,
                        durability: StorageDurabilityState = .durableLocal) -> GamificationEnrollmentService {
        service(Sched.repository(store, ids: Sched.UUIDSequence()), durability: durability)
    }

    /// The summary of a fresh enrollment; fails the test for any other result.
    static func enrolled(_ result: GamificationEnrollmentResult,
                         file: StaticString = #filePath, line: UInt = #line) throws -> GamificationEnrollmentSummary {
        guard case let .enrolled(summary) = result else {
            XCTFail("expected .enrolled, got \(result)", file: file, line: line)
            throw GamificationEnrollmentError.gamificationStorageUnavailable
        }
        return summary
    }

    static func summary(at: Date = Enroll.at, zone: String = Sched.la, baselines: Int) -> GamificationEnrollmentSummary {
        GamificationEnrollmentSummary(profileKey: "profile:v1:default", trackingStartedAt: at,
                                      schedulingTimeZoneIdentifier: zone, schedulingCalendarIdentifier: "gregorian",
                                      baselineRevisionCount: baselines)
    }

    /// Runs `body`, expects exactly `expected`, and asserts that no row of any table changed.
    static func assertRefused(_ expected: GamificationEnrollmentError,
                              store: ModelContainer,
                              file: StaticString = #filePath, line: UInt = #line,
                              _ body: () async throws -> GamificationEnrollmentResult) async throws {
        let before = try TxStore.state(store)
        do {
            let result = try await body()
            XCTFail("expected \(expected), got \(result)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? GamificationEnrollmentError, expected, "unexpected error: \(error)", file: file, line: line)
        }
        XCTAssertEqual(try TxStore.state(store), before, "a refused enrollment must write nothing", file: file, line: line)
    }

    // MARK: Seeding

    /// Representative current Habits covering every normalization branch, with their expected
    /// baseline payloads under the Los Angeles policy (literal values).
    static let representative: [(Sched.HabitSeed, Sched.Payload)] = [
        // Repeating Mon/Wed/Fri, reminder on at 07:30 LA.
        (Sched.HabitSeed(id: uuid(1), title: "Gym", icon: "atom", priority: .importantButNotUrgent, type: .repeating,
                         weekdays: [2, 4, 6], dueDate: Sched.at(day: 0, hour: 7, minute: 30), notification: true),
         Sched.Payload(target: uuid(1), taskType: "repeating", mask: 42, hour: 7, minute: 30, dueAt: nil,
                       priority: 2, icon: "atom", notification: true)),
        // Repeating Sun + Sat, reminder off: the stored clock (18:45) must not appear.
        (Sched.HabitSeed(id: uuid(2), title: "Laundry", icon: "bed", priority: .importantAndUrgent, type: .repeating,
                         weekdays: [7, 1], dueDate: Sched.at(day: 0, hour: 18, minute: 45), notification: false),
         Sched.Payload(target: uuid(2), taskType: "repeating", mask: 65, hour: nil, minute: nil, dueAt: nil,
                       priority: 0, icon: "bed", notification: false)),
        // One-time, reminder on, stale weekday values that must be ignored, no icon.
        (Sched.HabitSeed(id: uuid(3), title: "File taxes", icon: nil, priority: .urgentButNotImportant, type: .dueDate,
                         weekdays: [3], dueDate: Sched.at(day: 3, hour: 17, minute: 15), notification: true),
         Sched.Payload(target: uuid(3), taskType: "oneTime", mask: 0, hour: nil, minute: nil,
                       dueAt: Sched.at(day: 3, hour: 17, minute: 15), priority: 1, icon: nil, notification: true)),
        // One-time, reminder off: dueAt is kept.
        (Sched.HabitSeed(id: uuid(4), title: "Return book", icon: "book", priority: .notUrgentAndNotImportant, type: .dueDate,
                         weekdays: [], dueDate: Sched.at(day: 5, hour: 8), notification: false),
         Sched.Payload(target: uuid(4), taskType: "oneTime", mask: 0, hour: nil, minute: nil,
                       dueAt: Sched.at(day: 5, hour: 8), priority: 3, icon: "book", notification: false)),
        // Repeating every day, reminder on at 23:05 LA (already the next day in UTC and Tokyo).
        (Sched.HabitSeed(id: uuid(5), title: "Journal", icon: "leaf", priority: .notUrgentAndNotImportant, type: .repeating,
                         weekdays: [1, 2, 3, 4, 5, 6, 7], dueDate: Sched.at(day: 0, hour: 23, minute: 5), notification: true),
         Sched.Payload(target: uuid(5), taskType: "repeating", mask: 127, hour: 23, minute: 5, dueAt: nil,
                       priority: 3, icon: "leaf", notification: true)),
    ]

    static func seedRepresentative(_ store: ModelContainer) throws {
        for (seed, _) in representative { try Sched.seedHabit(store, seed) }
    }

    /// `count` ordinary repeating Habits with IDs `uuid(100 + i)`.
    static func seedHabits(_ store: ModelContainer, count: Int, firstIndex: Int = 100) throws -> [UUID] {
        try (0..<count).map { offset in
            let id = uuid(firstIndex + offset)
            try Sched.seedHabit(store, Sched.HabitSeed(id: id, title: "Habit \(offset)"))
            return id
        }
    }

    // MARK: Reading state back

    struct ProfileFacts: Equatable {
        let physicalID: UUID
        let logicalProfileKey: String
        let totalXP: Int
        let honkerCoins: Int
        let lifetimeCoinsEarned: Int
        let lifetimeCoinsSpent: Int
        let trackingStartedAt: Date?
        let schedulingTimeZoneIdentifier: String?
        let schedulingCalendarIdentifier: String?
        let lastProcessedWeekKey: String?
        let aggregateFingerprint: String?
        let schemaVersion: Int
        let updatedAt: Date?
    }

    static func profiles(_ store: ModelContainer) throws -> [ProfileFacts] {
        try ModelContext(store).fetch(FetchDescriptor<GamificationProfileSD>()).map {
            ProfileFacts(physicalID: $0.id, logicalProfileKey: $0.logicalProfileKey, totalXP: $0.totalXP,
                         honkerCoins: $0.honkerCoins, lifetimeCoinsEarned: $0.lifetimeCoinsEarned,
                         lifetimeCoinsSpent: $0.lifetimeCoinsSpent, trackingStartedAt: $0.trackingStartedAt,
                         schedulingTimeZoneIdentifier: $0.schedulingTimeZoneIdentifier,
                         schedulingCalendarIdentifier: $0.schedulingCalendarIdentifier,
                         lastProcessedWeekKey: $0.lastProcessedWeekKey, aggregateFingerprint: $0.aggregateFingerprint,
                         schemaVersion: $0.schemaVersion, updatedAt: $0.updatedAt)
        }.sorted { $0.physicalID.uuidString < $1.physicalID.uuidString }
    }

    static func onlyProfile(_ store: ModelContainer, file: StaticString = #filePath, line: UInt = #line) throws -> ProfileFacts {
        let rows = try profiles(store)
        XCTAssertEqual(rows.count, 1, "profile rows", file: file, line: line)
        return try XCTUnwrap(rows.first, file: file, line: line)
    }

    /// Every revision row of every target.
    static func allRows(_ store: ModelContainer) throws -> [Sched.Row] {
        try Sched.rows(store, target: nil)
    }

    /// The zero-balance profile a fresh enrollment at `at` in `zone` must produce (physical id excluded).
    static func assertZeroProjection(_ profile: ProfileFacts, at: Date = Enroll.at, zone: String = Sched.la,
                                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(profile.logicalProfileKey, "profile:v1:default", file: file, line: line)
        XCTAssertEqual(profile.totalXP, 0, file: file, line: line)
        XCTAssertEqual(profile.honkerCoins, 0, file: file, line: line)
        XCTAssertEqual(profile.lifetimeCoinsEarned, 0, file: file, line: line)
        XCTAssertEqual(profile.lifetimeCoinsSpent, 0, file: file, line: line)
        XCTAssertEqual(profile.trackingStartedAt, at, file: file, line: line)
        XCTAssertEqual(profile.schedulingTimeZoneIdentifier, zone, file: file, line: line)
        XCTAssertEqual(profile.schedulingCalendarIdentifier, "gregorian", file: file, line: line)
        XCTAssertNil(profile.lastProcessedWeekKey, file: file, line: line)
        XCTAssertNil(profile.aggregateFingerprint, file: file, line: line)
        XCTAssertEqual(profile.schemaVersion, 1, file: file, line: line)
        XCTAssertEqual(profile.updatedAt, at, file: file, line: line)
    }

    /// Occurrence, event and ledger rows: enrollment must never write any.
    static func assertNoRewardRows(_ store: ModelContainer, file: StaticString = #filePath, line: UInt = #line) throws {
        let counts = try Sched.otherGamificationCounts(store)
        XCTAssertEqual(counts.occurrences, 0, "TaskOccurrenceSD", file: file, line: line)
        XCTAssertEqual(counts.events, 0, "BehaviorEventSD", file: file, line: line)
        XCTAssertEqual(counts.ledger, 0, "GamificationLedgerEntrySD", file: file, line: line)
    }

    /// Runs `body` with both the system zone (`TimeZone.current`) and the default zone switched to
    /// `identifier`, restoring both afterwards (same technique as the 4B B82 test).
    static func withDeviceTimeZone(_ identifier: String, _ body: () async throws -> Void) async throws {
        let zone = try XCTUnwrap(TimeZone(identifier: identifier))
        let savedTZ = getenv("TZ").map { String(cString: $0) }
        let savedTZFile = getenv("TZFILE").map { String(cString: $0) }
        let savedDefault = NSTimeZone.default
        defer {
            if let savedTZ { _ = setenv("TZ", savedTZ, 1) } else { _ = unsetenv("TZ") }
            if let savedTZFile { _ = setenv("TZFILE", savedTZFile, 1) } else { _ = unsetenv("TZFILE") }
            NSTimeZone.resetSystemTimeZone()
            NSTimeZone.default = savedDefault
        }
        _ = unsetenv("TZFILE")
        _ = setenv("TZ", identifier, 1)
        NSTimeZone.resetSystemTimeZone()
        NSTimeZone.default = zone
        try await body()
    }
}

/// Service-level test double: records every request that reaches the repository boundary.
final class RecordingEnrollmentRepository: GamificationEnrollmentRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var received: [GamificationEnrollmentRequest] = []
    private let result: GamificationEnrollmentResult

    init(result: GamificationEnrollmentResult) {
        self.result = result
    }

    var requests: [GamificationEnrollmentRequest] {
        lock.lock(); defer { lock.unlock() }
        return received
    }

    func enroll(_ request: GamificationEnrollmentRequest) async throws -> GamificationEnrollmentResult {
        lock.lock(); received.append(request); lock.unlock()
        return result
    }
}

/// Legacy completion day policy for enrollment tests: Gregorian, Los Angeles.
func enrollmentLACalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: Sched.la)!
    return calendar
}
