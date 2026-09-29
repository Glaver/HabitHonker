import Combine
import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4B fixtures.
///
/// Enrollment is seeded by hand (Phase 4E does not exist yet). Revision payloads are literal values,
/// independent of the production normalizer. Revision IDs come from the production V1 provider fed
/// with a deterministic UUID sequence. Times are wall-clock instants in Los Angeles, computed on an
/// explicit Gregorian calendar, so no fixture depends on the device's time zone.
enum Sched {
    static let targetUUID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
    static let target = BehaviorTargetID(targetUUID)
    static let targetText = "123e4567-e89b-12d3-a456-426614174000"
    static let otherUUID = UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!
    static let otherText = "a0b1c2d3-e4f5-4678-9abc-def012345678"
    static let la = "America/Los_Angeles"
    static let gregorian = "gregorian"
    static let profileKey = "profile:v1:default"
    static let baselineID = "rev:v1:123e4567-e89b-12d3-a456-426614174000:baseline"

    /// Wall-clock instant on 2027-01-(11 + day) in `zone`. 2027-01-11 is a Monday.
    static func at(day: Int, hour: Int, minute: Int = 0, zone: String = la) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar.date(from: DateComponents(year: 2027, month: 1, day: 11 + day, hour: hour, minute: minute))!
    }

    /// Enrollment instant of the seeded profile: Monday 2027-01-11 09:00 Los Angeles.
    static let trackingStartedAt = at(day: 0, hour: 9)
    /// The seeded repeating Habit's reminder instant: 07:30 Los Angeles.
    static let reminder = at(day: 0, hour: 7, minute: 30)

    // MARK: Revision IDs

    /// `AAAAAAAA-BBBB-CCCC-DDDD-00000000000n`
    static func revisionUUID(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "AAAAAAAA-BBBB-CCCC-DDDD-%012d", n))!
    }

    /// The n-th normal revision ID minted by a fresh `UUIDSequence` for `target`.
    static func changeID(_ n: Int, target: String = targetText) -> String {
        "rev:v1:\(target):change:aaaaaaaa-bbbb-cccc-dddd-\(String(format: "%012d", n))"
    }

    /// Thread-safe deterministic UUID source that also counts how many IDs were minted.
    final class UUIDSequence: @unchecked Sendable {
        private let lock = NSLock()
        private var issued = 0

        func next() -> UUID {
            lock.lock(); defer { lock.unlock() }
            issued += 1
            return Sched.revisionUUID(issued)
        }

        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return issued
        }
    }

    /// The production actor with the production planner and the production V1 ID provider,
    /// fed with deterministic UUIDs.
    static func repository(_ store: ModelContainer, ids: UUIDSequence) -> HabitsRepositorySwiftData {
        HabitsRepositorySwiftData(container: store,
                                  scheduleRevisionIDs: BehaviorScheduleRevisionIDProviderV1(uuid: { ids.next() }))
    }

    // MARK: Stores and seeding

    /// Profile + default Habit + its matching open baseline revision.
    @MainActor
    static func enrolledStore(habit: HabitSeed = HabitSeed(),
                              baseline: RevisionSeed = RevisionSeed()) throws -> ModelContainer {
        let store = try TxStore.memory()
        try seedProfile(store)
        try seedHabit(store, habit)
        try seedRevision(store, baseline)
        return store
    }

    static func seedProfile(_ store: ModelContainer,
                            trackingStartedAt: Date? = Sched.trackingStartedAt,
                            timeZone: String? = Sched.la,
                            calendar: String? = Sched.gregorian,
                            key: String = Sched.profileKey,
                            totalXP: Int = 0,
                            honkerCoins: Int = 0,
                            lifetimeCoinsEarned: Int = 0,
                            lifetimeCoinsSpent: Int = 0) throws {
        let context = ModelContext(store)
        context.insert(GamificationProfileSD(logicalProfileKey: key, totalXP: totalXP, honkerCoins: honkerCoins,
                                             lifetimeCoinsEarned: lifetimeCoinsEarned, lifetimeCoinsSpent: lifetimeCoinsSpent,
                                             trackingStartedAt: trackingStartedAt,
                                             schedulingTimeZoneIdentifier: timeZone,
                                             schedulingCalendarIdentifier: calendar))
        try context.save()
    }

    /// Default: repeating Mon/Wed/Fri, reminder on at 07:30 LA, Important / Not Urgent, icon "atom".
    struct HabitSeed {
        var id = Sched.targetUUID
        var title = "Gym"
        var icon: String? = "atom"
        var colorHex: String? = "#FF0000FF"
        var priority: PriorityEisenhower = .importantButNotUrgent
        var type: HabitType = .repeating
        var weekdays: [Int] = [2, 4, 6]
        var dueDate = Sched.reminder
        var notification = true
        var records: [(UUID, Date, Int)] = []
    }

    static func seedHabit(_ store: ModelContainer, _ seed: HabitSeed = HabitSeed()) throws {
        let context = ModelContext(store)
        let habit = HabitSD(id: seed.id, icon: seed.icon, iconColorHex: seed.colorHex, title: seed.title,
                            descriptionText: "Legs", tags: ["health"], priorityRaw: seed.priority.rawValue,
                            typeRaw: seed.type.rawValue, repeatingWeekdays: seed.weekdays, dueDate: seed.dueDate,
                            notificationActivated: seed.notification, records: [])
        context.insert(habit)
        var rows: [HabitRecordSD] = []
        for (recordID, date, count) in seed.records {
            let row = HabitRecordSD(id: recordID, date: date, count: count, habit: habit)
            context.insert(row)
            rows.append(row)
        }
        habit.records = rows
        try context.save()
    }

    /// Archived (deleted) Habit with the default seed's metadata.
    static func seedArchive(_ store: ModelContainer, _ seed: HabitSeed = HabitSeed(), deletedAt: Date) throws {
        let context = ModelContext(store)
        context.insert(DeletedHabitSD(id: seed.id, icon: seed.icon, iconColorHex: seed.colorHex ?? "#000000FF",
                                      title: seed.title, descriptionText: "Legs", tags: ["health"],
                                      priorityRaw: seed.priority.rawValue, typeRaw: seed.type.rawValue,
                                      repeatingWeekdays: seed.weekdays, dueDate: seed.dueDate,
                                      notificationActivated: seed.notification, deletedAt: deletedAt, records: []))
        try context.save()
    }

    /// The literal planning payload of a revision row. Defaults describe the default `HabitSeed`
    /// under the default profile policy.
    struct Payload: Equatable {
        var target = Sched.targetUUID
        var taskType = "repeating"
        var mask = 42
        var hour: Int? = 7
        var minute: Int? = 30
        var dueAt: Date? = nil
        var timeZone: String? = Sched.la
        var calendar: String? = Sched.gregorian
        var priority: Int? = BehaviorPriority.importantButNotUrgent.rawValue
        var icon: String? = "atom"
        var notification: Bool? = true
        var schemaVersion = 1
    }

    struct RevisionSeed {
        var logicalID = Sched.baselineID
        var from = Sched.trackingStartedAt
        var to: Date? = nil
        var payload = Payload()
    }

    static func seedRevision(_ store: ModelContainer, _ seed: RevisionSeed = RevisionSeed()) throws {
        let context = ModelContext(store)
        let p = seed.payload
        context.insert(BehaviorScheduleRevisionSD(logicalRevisionID: seed.logicalID, targetID: p.target,
                                                  effectiveFrom: seed.from, effectiveTo: seed.to,
                                                  taskTypeRawValue: p.taskType, selectedWeekdaysMask: p.mask,
                                                  scheduledHour: p.hour, scheduledMinute: p.minute, dueAt: p.dueAt,
                                                  schedulingTimeZoneIdentifier: p.timeZone,
                                                  schedulingCalendarIdentifier: p.calendar,
                                                  priorityRawValue: p.priority, iconName: p.icon,
                                                  notificationEnabled: p.notification, schemaVersion: p.schemaVersion))
        try context.save()
    }

    /// Metadata equal to the default `HabitSeed` in every revision-relevant field.
    static func metadata(_ change: (inout HabitMetadata) -> Void = { _ in }) -> HabitMetadata {
        var metadata = HabitMetadata(icon: "atom", iconColor: .red, title: "Gym", description: "Legs", tags: ["health"],
                                     priority: .importantButNotUrgent, type: .repeating,
                                     repeating: [.monday, .wednesday, .friday], dueDate: Sched.reminder,
                                     isNotificationActivated: true)
        change(&metadata)
        return metadata
    }

    // MARK: Reading state back (fresh contexts, value copies)

    struct Row: Equatable {
        let physicalID: UUID
        let logicalRevisionID: String
        let effectiveFrom: Date
        let effectiveTo: Date?
        let payload: Payload
    }

    /// Every revision row (of `target`, or of all targets when nil), ordered by effectiveFrom,
    /// then logical ID, then open rows last.
    static func rows(_ store: ModelContainer, target: UUID? = Sched.targetUUID) throws -> [Row] {
        try ModelContext(store).fetch(FetchDescriptor<BehaviorScheduleRevisionSD>())
            .filter { target == nil || $0.targetID == target }
            .map { row in
                Row(physicalID: row.id, logicalRevisionID: row.logicalRevisionID,
                    effectiveFrom: row.effectiveFrom, effectiveTo: row.effectiveTo,
                    payload: Payload(target: row.targetID, taskType: row.taskTypeRawValue, mask: row.selectedWeekdaysMask,
                                     hour: row.scheduledHour, minute: row.scheduledMinute, dueAt: row.dueAt,
                                     timeZone: row.schedulingTimeZoneIdentifier,
                                     calendar: row.schedulingCalendarIdentifier,
                                     priority: row.priorityRawValue, icon: row.iconName,
                                     notification: row.notificationEnabled, schemaVersion: row.schemaVersion))
            }
            .sorted { lhs, rhs in
                if lhs.effectiveFrom != rhs.effectiveFrom { return lhs.effectiveFrom < rhs.effectiveFrom }
                if lhs.logicalRevisionID != rhs.logicalRevisionID { return lhs.logicalRevisionID < rhs.logicalRevisionID }
                return lhs.effectiveTo != nil && rhs.effectiveTo == nil
            }
    }

    static func row(_ rows: [Row], _ logicalID: String) throws -> Row {
        let matches = rows.filter { $0.logicalRevisionID == logicalID }
        XCTAssertEqual(matches.count, 1, "rows with logical ID \(logicalID)")
        return try XCTUnwrap(matches.first)
    }

    static func habitCount(_ store: ModelContainer, id: UUID = Sched.targetUUID) throws -> Int {
        try ModelContext(store).fetchCount(FetchDescriptor<HabitSD>(predicate: #Predicate<HabitSD> { $0.id == id }))
    }

    static func archiveCount(_ store: ModelContainer, id: UUID = Sched.targetUUID) throws -> Int {
        try ModelContext(store).fetchCount(FetchDescriptor<DeletedHabitSD>(predicate: #Predicate<DeletedHabitSD> { $0.id == id }))
    }

    /// Stored current-Habit fields as plain values.
    struct HabitFacts: Equatable {
        let title: String
        let priorityRaw: Int
        let typeRaw: Int
        let weekdays: [Int]
        let dueDate: Date
        let notification: Bool
        let icon: String?
    }

    static func habitFacts(_ store: ModelContainer, id: UUID = Sched.targetUUID) throws -> HabitFacts {
        let rows = try ModelContext(store).fetch(FetchDescriptor<HabitSD>(predicate: #Predicate<HabitSD> { $0.id == id }))
        XCTAssertEqual(rows.count, 1)
        let habit = try XCTUnwrap(rows.first)
        return HabitFacts(title: habit.title, priorityRaw: habit.priorityRaw, typeRaw: habit.typeRaw,
                          weekdays: habit.repeatingWeekdays.sorted(), dueDate: habit.dueDate,
                          notification: habit.notificationActivated, icon: habit.icon)
    }

    struct RecordFact: Hashable {
        let id: UUID
        let date: Date
        let count: Int
    }

    static func recordFacts(_ store: ModelContainer, habitID: UUID = Sched.targetUUID) throws -> Set<RecordFact> {
        let rows = try ModelContext(store).fetch(FetchDescriptor<HabitSD>(predicate: #Predicate<HabitSD> { $0.id == habitID }))
        let habit = try XCTUnwrap(rows.first)
        return Set((habit.records ?? []).map { RecordFact(id: $0.id, date: $0.date, count: $0.count) })
    }

    static func recordRowCount(_ store: ModelContainer) throws -> Int {
        try ModelContext(store).fetchCount(FetchDescriptor<HabitRecordSD>())
    }

    /// Row counts of the gamification tables 4B must never write.
    struct OtherGamificationCounts: Equatable {
        let occurrences: Int
        let events: Int
        let ledger: Int
        let profiles: Int
    }

    static func otherGamificationCounts(_ store: ModelContainer) throws -> OtherGamificationCounts {
        let context = ModelContext(store)
        return OtherGamificationCounts(occurrences: try context.fetchCount(FetchDescriptor<TaskOccurrenceSD>()),
                                       events: try context.fetchCount(FetchDescriptor<BehaviorEventSD>()),
                                       ledger: try context.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()),
                                       profiles: try context.fetchCount(FetchDescriptor<GamificationProfileSD>()))
    }

    /// Every stored field of every profile row.
    @MainActor
    static func profileState(_ store: ModelContainer) throws -> [String: [String: AnyHashable?]] {
        try TxStore.state(store).filter { $0.key.hasPrefix("GamificationProfileSD:") }
    }

    /// Every stored field of every revision row.
    @MainActor
    static func revisionState(_ store: ModelContainer) throws -> [String: [String: AnyHashable?]] {
        try TxStore.state(store).filter { $0.key.hasPrefix("BehaviorScheduleRevisionSD:") }
    }

    /// A failure injected after a mutation staged its whole write set, before its single save.
    enum InjectedFailure: Error, Equatable {
        case beforeCommit
    }

    static var injected: InjectedFailure { .beforeCommit }

    static func assertInjected(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(error as? InjectedFailure, .beforeCommit, "unexpected error: \(error)", file: file, line: line)
    }
}

/// Mutable test clock read by an injected `now` closure; thread-safe for concurrent services.
final class ScheduleTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ now: Date) { value = now }

    var now: Date {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); defer { lock.unlock() }; value = newValue }
    }
}

/// Discards `HabitService` events.
final class ScheduleSilentEvents: HabitEventsPublishing {
    var events: AnyPublisher<HabitEvent, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }
    func send(_ event: HabitEvent) {}
}
