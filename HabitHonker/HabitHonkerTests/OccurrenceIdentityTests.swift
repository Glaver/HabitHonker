import Foundation
import XCTest
@testable import HabitHonker

/// Phase 4C: the frozen V1 logical identity keys, built only from the minimal approved facts.
/// Pure: no persistence, no device calendar, time zone or locale, nothing random.
final class OccurrenceIdentityTests: XCTestCase {
    /// The v1.1.2 contract's format example.
    private static let exampleTarget = BehaviorTargetID(UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!)
    /// The v1.1.2 contract's UUID-normalization example: mostly alphabetic hex digits.
    private static let mixedCaseTarget = BehaviorTargetID(UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!)

    private let identity = OccurrenceIdentityV1()
    private let calculator = GregorianLocalDayCalculator()

    // MARK: C17–C21 — the frozen V1 formats, exactly

    func testC17CanonicalProfileKeyIsExact() {
        XCTAssertEqual(BehaviorLogicalIdentity.defaultProfileKey, "profile:v1:default")
    }

    func testC18BaselineRevisionIDIsExact() {
        XCTAssertEqual(BehaviorLogicalIdentity.baselineRevisionID(targetID: Self.exampleTarget),
                       "rev:v1:123e4567-e89b-12d3-a456-426614174000:baseline")
    }

    func testC19OneTimeOccurrenceIDIsExact() {
        XCTAssertEqual(identity.oneTimeOccurrenceID(targetID: Self.exampleTarget),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:once")
    }

    func testC20RepeatingOccurrenceIDIsExact() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: day),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-28")
    }

    func testC21AlphabeticHexDigitsAreLowercasedInEveryKey() throws {
        let foundationText = Self.mixedCaseTarget.rawValue.uuidString
        XCTAssertNotEqual(foundationText, foundationText.lowercased(), "Foundation's UUID text is uppercase; keys must not be")
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "UTC")

        let keys = [
            identity.oneTimeOccurrenceID(targetID: Self.mixedCaseTarget),
            identity.repeatingOccurrenceID(targetID: Self.mixedCaseTarget, localDay: day),
            BehaviorLogicalIdentity.baselineRevisionID(targetID: Self.mixedCaseTarget),
        ]

        XCTAssertEqual(BehaviorLogicalIdentity.canonicalUUIDText(Self.mixedCaseTarget.rawValue),
                       "a0b1c2d3-e4f5-4678-9abc-def012345678")
        XCTAssertEqual(keys, [
            "occ:v1:a0b1c2d3-e4f5-4678-9abc-def012345678:once",
            "occ:v1:a0b1c2d3-e4f5-4678-9abc-def012345678:day:2026-09-28",
            "rev:v1:a0b1c2d3-e4f5-4678-9abc-def012345678:baseline",
        ])
        // I6: plain lowercase ASCII only, so no locale can render a key differently.
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789:-")
        for key in keys + [BehaviorLogicalIdentity.defaultProfileKey] {
            XCTAssertTrue(key.allSatisfy { allowed.contains($0) }, key)
        }
    }

    // MARK: C22–C24 — deterministic, and distinct where the facts differ (I1, I2, I3, I5)

    func testC22SameTargetAndDayGiveTheSameKeyAcrossIndependentInstances() throws {
        // The same civil date reached two independent ways…
        let fromComponents = try GregorianLocalDayCalculator().localDay(year: 2026, month: 9, day: 28,
                                                                        timeZoneIdentifier: "America/Los_Angeles")
        let fromInstant = try GregorianLocalDayCalculator().localDay(containing: instant("2026-09-28T19:00:00Z"),
                                                                     timeZoneIdentifier: "America/Los_Angeles")
        // …and the same target as it reads back from stored lowercase text after a relaunch.
        let reloadedTarget = BehaviorTargetID(UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!)
        let viaProtocol: any OccurrenceIdentifying = OccurrenceIdentityV1()

        let first = OccurrenceIdentityV1().repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: fromComponents)
        let second = OccurrenceIdentityV1().repeatingOccurrenceID(targetID: reloadedTarget, localDay: fromInstant)

        XCTAssertEqual(fromComponents, fromInstant)
        XCTAssertEqual(first, second)
        XCTAssertEqual(viaProtocol.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: fromInstant), first)
        XCTAssertEqual(OccurrenceIdentityV1().oneTimeOccurrenceID(targetID: reloadedTarget),
                       OccurrenceIdentityV1().oneTimeOccurrenceID(targetID: Self.exampleTarget))
        XCTAssertEqual(BehaviorLogicalIdentity.baselineRevisionID(targetID: reloadedTarget),
                       BehaviorLogicalIdentity.baselineRevisionID(targetID: Self.exampleTarget))
    }

    func testC23NeighboringDaysGiveDifferentKeys() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "America/Los_Angeles")
        let previous = try calculator.localDay(containing: day.start.addingTimeInterval(-1),
                                               timeZoneIdentifier: "America/Los_Angeles")
        let next = try calculator.localDay(containing: day.end, timeZoneIdentifier: "America/Los_Angeles")

        let keys = [previous, day, next].map { identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: $0) }

        XCTAssertEqual(keys, [
            "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-27",
            "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-28",
            "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-29",
        ])
        XCTAssertEqual(Set(keys).count, 3)
    }

    func testC24DifferentTargetsOnTheSameDayGiveDifferentKeys() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertNotEqual(identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: day),
                          identity.repeatingOccurrenceID(targetID: Self.mixedCaseTarget, localDay: day))
        XCTAssertNotEqual(identity.oneTimeOccurrenceID(targetID: Self.exampleTarget),
                          identity.oneTimeOccurrenceID(targetID: Self.mixedCaseTarget))
        XCTAssertNotEqual(BehaviorLogicalIdentity.baselineRevisionID(targetID: Self.exampleTarget),
                          BehaviorLogicalIdentity.baselineRevisionID(targetID: Self.mixedCaseTarget))
        // The different kinds of key never collide for one target either.
        let kinds = [identity.oneTimeOccurrenceID(targetID: Self.exampleTarget),
                     identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: day),
                     BehaviorLogicalIdentity.baselineRevisionID(targetID: Self.exampleTarget),
                     BehaviorLogicalIdentity.defaultProfileKey]
        XCTAssertEqual(Set(kinds).count, kinds.count)
    }

    // MARK: C25–C26 — identity takes only the approved facts (I4)

    func testC25OneTimeIdentityIgnoresDueDateEdits() {
        var task = BehaviorTarget(id: Self.exampleTarget, title: "File taxes",
                                  schedule: .oneTime(dueDate: instant("2026-09-28T09:00:00Z")))
        let original = identity.oneTimeOccurrenceID(targetID: task.id)

        for editedDueDate in [instant("2026-09-30T17:30:00Z"), instant("2027-04-15T06:59:59Z"), instant("2025-01-01T00:00:00Z")] {
            task.schedule = .oneTime(dueDate: editedDueDate)
            XCTAssertEqual(identity.oneTimeOccurrenceID(targetID: task.id), original)
        }
        XCTAssertEqual(original, "occ:v1:123e4567-e89b-12d3-a456-426614174000:once")

        // There is no due-date input at all: the full name and function type are frozen at compile time.
        let oneTime: (OccurrenceIdentityV1) -> (BehaviorTargetID) -> String = OccurrenceIdentityV1.oneTimeOccurrenceID(targetID:)
        XCTAssertEqual(oneTime(OccurrenceIdentityV1())(Self.exampleTarget), original)
    }

    func testC26RepeatingIdentityIgnoresPriorityTitleNotificationAndSchedule() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "America/Los_Angeles")
        let original = BehaviorTarget(id: Self.exampleTarget, title: "Gym", priority: .importantAndUrgent,
                                      schedule: .repeating(weekdays: [.monday]))
        let edited = BehaviorTarget(id: Self.exampleTarget, iconName: "figure.run", title: "Evening gym",
                                    description: "edited", tags: ["health"], priority: .notUrgentAndNotImportant,
                                    schedule: .repeating(weekdays: [.monday, .thursday]),
                                    reminderConfig: TargetReminderConfig(isEnabled: true,
                                                                         deliveryTime: instant("2026-09-28T16:00:00Z")))

        XCTAssertEqual(identity.repeatingOccurrenceID(targetID: original.id, localDay: day),
                       identity.repeatingOccurrenceID(targetID: edited.id, localDay: day))

        // Those facts are not inputs: the full name and function type are frozen at compile time…
        let repeating: (OccurrenceIdentityV1) -> (BehaviorTargetID, LocalDay) -> String =
            OccurrenceIdentityV1.repeatingOccurrenceID(targetID:localDay:)
        XCTAssertEqual(repeating(OccurrenceIdentityV1())(Self.exampleTarget, day),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-28")
        // …and the protocol and its V1 implementation declare exactly these two operations.
        let expected = ["func repeatingOccurrenceID(targetID: BehaviorTargetID, localDay: LocalDay) -> String",
                        "func oneTimeOccurrenceID(targetID: BehaviorTargetID) -> String"]
        for path in ["Core/Protocols/OccurrenceIdentifying.swift", "Core/Domain/OccurrenceIdentityV1.swift"] {
            let signatures = try functionSignatures(in: path)
            XCTAssertEqual(signatures, expected, path)
            let inputs = signatures.joined(separator: " ").lowercased()
            for fact in ["priority", "title", "notification", "reminder", "revision", "schedule", "due", "date",
                         "completion", "streak", "reward", "icon"] {
                XCTAssertFalse(inputs.contains(fact), "\(path): identity input mentions \(fact)")
            }
        }
    }

    // MARK: C27–C29 — calendar edge cases reach the key intact

    func testC27LeapDayOccurrenceKey() throws {
        let leapDay = try calculator.localDay(year: 2028, month: 2, day: 29, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: leapDay),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2028-02-29")
    }

    func testC28YearBoundaryOccurrenceKeys() throws {
        let newYearsEve = try calculator.localDay(year: 2026, month: 12, day: 31, timeZoneIdentifier: "America/Los_Angeles")
        let newYearsDay = try calculator.localDay(containing: newYearsEve.end, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: newYearsEve),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-12-31")
        XCTAssertEqual(identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: newYearsDay),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2027-01-01")
    }

    func testC29OneInstantUnderTwoZonesGivesTwoDaysAndTwoKeys() throws {
        let moment = instant("2026-09-28T05:30:00Z") // 22:30 Sep 27 in Los Angeles, 14:30 Sep 28 in Tokyo
        let losAngeles = try calculator.localDay(containing: moment, timeZoneIdentifier: "America/Los_Angeles")
        let tokyo = try calculator.localDay(containing: moment, timeZoneIdentifier: "Asia/Tokyo")

        XCTAssertEqual(identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: losAngeles),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-27")
        XCTAssertEqual(identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: tokyo),
                       "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-28")

        // The key names the civil date, not the zone: when the zones agree on the date, so do the keys.
        // Which zone governs gamification is the profile's decision (Phase 4E), not the key's.
        let noon = instant("2026-09-28T12:00:00Z") // 05:00 in Los Angeles, 21:00 in Tokyo
        XCTAssertEqual(
            identity.repeatingOccurrenceID(targetID: Self.exampleTarget,
                                           localDay: try calculator.localDay(containing: noon, timeZoneIdentifier: "America/Los_Angeles")),
            identity.repeatingOccurrenceID(targetID: Self.exampleTarget,
                                           localDay: try calculator.localDay(containing: noon, timeZoneIdentifier: "Asia/Tokyo")))
    }

    // MARK: C30 — nothing random: the only UUID in any key is the supplied target

    func testC30KeysContainNoUUIDOtherThanTheSuppliedTarget() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "UTC")
        let target = Self.mixedCaseTarget
        func keys() -> [String] {
            [OccurrenceIdentityV1().oneTimeOccurrenceID(targetID: target),
             OccurrenceIdentityV1().repeatingOccurrenceID(targetID: target, localDay: day),
             BehaviorLogicalIdentity.baselineRevisionID(targetID: target)]
        }
        let first = keys()

        XCTAssertEqual(keys(), first, "Recomputing mints nothing new")
        for key in first {
            XCTAssertEqual(try uuidShapedRuns(in: key), ["a0b1c2d3-e4f5-4678-9abc-def012345678"], key)
        }
        XCTAssertEqual(try uuidShapedRuns(in: BehaviorLogicalIdentity.defaultProfileKey), [])
        XCTAssertEqual(first.map { $0.replacingOccurrences(of: "a0b1c2d3-e4f5-4678-9abc-def012345678", with: "<target>") },
                       ["occ:v1:<target>:once", "occ:v1:<target>:day:2026-09-28", "rev:v1:<target>:baseline"])
    }

    // MARK: I8, I9 — the device time zone never takes part; daylight saving never reaches the key

    func testI8DeviceTimeZoneChangesDoNotChangeDaysOrKeys() throws {
        let moment = instant("2026-09-28T05:30:00Z")
        let expectedDay = try calculator.localDay(containing: moment, timeZoneIdentifier: "America/Los_Angeles")
        let expectedKey = identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: expectedDay)

        let originalDefault = NSTimeZone.default
        defer { NSTimeZone.default = originalDefault }
        for deviceZone in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "Asia/Kolkata", "Europe/London"] {
            // The in-process equivalent of the user moving the device to another time zone.
            NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: deviceZone))
            let day = try GregorianLocalDayCalculator().localDay(containing: moment, timeZoneIdentifier: "America/Los_Angeles")

            XCTAssertEqual(day, expectedDay, deviceZone)
            XCTAssertEqual(OccurrenceIdentityV1().repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: day),
                           expectedKey, deviceZone)
        }
        XCTAssertEqual(expectedKey, "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-27")
    }

    func testI9DaylightSavingChangesDurationNotKeyFormat() throws {
        let zone = "America/Los_Angeles"
        let days = [try calculator.localDay(year: 2026, month: 3, day: 8, timeZoneIdentifier: zone),
                    try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: zone),
                    try calculator.localDay(year: 2026, month: 11, day: 1, timeZoneIdentifier: zone)]

        let expectedDurations: [TimeInterval] = [
            23 * 3_600,
            24 * 3_600,
            25 * 3_600
        ]

        XCTAssertEqual(days.map(\.duration), expectedDurations)
        XCTAssertEqual(days.map { identity.repeatingOccurrenceID(targetID: Self.exampleTarget, localDay: $0) }, [
            "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-03-08",
            "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-09-28",
            "occ:v1:123e4567-e89b-12d3-a456-426614174000:day:2026-11-01",
        ])
    }

    // MARK: Guard — the new 4C production files are pure Foundation domain code

    private static let phase4CProductionFiles = [
        "Core/Domain/LocalDay.swift",
        "Core/Domain/BehaviorLogicalIdentity.swift",
        "Core/Domain/OccurrenceIdentityV1.swift",
        "Core/Protocols/LocalDayCalculating.swift",
        "Core/Protocols/OccurrenceIdentifying.swift",
    ]

    func testGuardPhase4CFilesArePureFoundationWithoutDeviceStateHashingOrRandomness() throws {
        let forbidden = [
            // persistence, UI and reactive frameworks
            "import SwiftUI", "import SwiftData", "import CloudKit", "import Combine", "import UIKit", "import CoreData",
            "ModelContext", "ModelContainer", "@Model", "FetchDescriptor", "UserDefaults",
            // the device's calendar, time zone and locale
            "Calendar.current", "Calendar.autoupdatingCurrent", "TimeZone.current", "TimeZone.autoupdatingCurrent",
            "Locale.current", "Locale.autoupdatingCurrent", "NSCalendar", "NSTimeZone", "NSLocale",
            // localized or implicit text
            "DateFormatter", "String(format", ".description", ".debugDescription", "String(describing",
            // hashing and minted identifiers (UUID as a type is fine; constructing one is not)
            "Hasher(", "hashValue", "UUID(", "NSUUID",
            // clock reads and fixed-length days
            "Date()", "Date.now", "Date(timeInterval", "timeIntervalSinceNow", "addingTimeInterval", "86400", "86_400",
        ]
        for path in Self.phase4CProductionFiles {
            let source = try productionSource(path)
            let imports = source.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") }

            XCTAssertEqual(imports, ["import Foundation"], path)
            for token in forbidden {
                XCTAssertFalse(source.contains(token), "\(path) contains \(token)")
            }
            XCTAssertFalse(source.lowercased().contains("random"), "\(path) mentions randomness")
        }

        // The only calendar is an explicitly constructed Gregorian one in the requested zone,
        // and a day's end comes from calendar arithmetic.
        let localDay = try productionSource("Core/Domain/LocalDay.swift")
        XCTAssertEqual(localDay.components(separatedBy: "Calendar(identifier:").count - 1, 1)
        XCTAssertTrue(localDay.contains("Calendar(identifier: .gregorian)"))
        XCTAssertTrue(localDay.contains("TimeZone(identifier: timeZoneIdentifier)"))
        XCTAssertTrue(localDay.contains("date(byAdding: .day, value: 1"))
        // Only the calculator can create a LocalDay, so every value is a validated Gregorian day.
        XCTAssertTrue(localDay.contains("fileprivate init(year: Int, month: Int, day: Int"))
    }

    // MARK: - Helpers

    private func instant(_ iso8601: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: iso8601) else {
            preconditionFailure("Bad test fixture \(iso8601)")
        }
        return date
    }

    private func productionSource(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HabitHonker")
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// The trimmed `func` declarations of a production file, without an opening brace.
    private func functionSignatures(in path: String) throws -> [String] {
        try productionSource(path)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("func ") }
            .map { $0.hasSuffix("{") ? String($0.dropLast()).trimmingCharacters(in: .whitespaces) : $0 }
    }

    private func uuidShapedRuns(in key: String) throws -> [String] {
        let hex = "[0-9A-Fa-f]"
        let regex = try NSRegularExpression(pattern: "\(hex){8}-\(hex){4}-\(hex){4}-\(hex){4}-\(hex){12}")
        return regex.matches(in: key, range: NSRange(key.startIndex..., in: key)).compactMap { match in
            Range(match.range, in: key).map { String(key[$0]) }
        }
    }
}
