import Foundation
import XCTest
@testable import HabitHonker

/// Phase 4C: Gregorian civil days in an explicit scheduling time zone, with exact
/// half-open bounds. Pure: no persistence, no device calendar, time zone or locale.
final class LocalDayTests: XCTestCase {
    private let calculator = GregorianLocalDayCalculator()

    // MARK: C1–C2 — canonical YYYY-MM-DD

    func testC1UTCNormalDay() throws {
        let day = try calculator.localDay(containing: instant("2026-09-28T12:34:56Z"), timeZoneIdentifier: "UTC")

        XCTAssertEqual(day.canonicalKey, "2026-09-28")
        XCTAssertEqual([day.year, day.month, day.day], [2026, 9, 28])
        XCTAssertEqual(day.timeZoneIdentifier, "UTC")
        XCTAssertEqual(day.start, instant("2026-09-28T00:00:00Z"))
        XCTAssertEqual(day.end, instant("2026-09-29T00:00:00Z"))
        XCTAssertEqual(day.duration, 24 * 3_600)
    }

    func testC2SingleDigitMonthAndDayAreZeroPadded() throws {
        let fromInstant = try calculator.localDay(containing: instant("2026-01-03T09:00:00Z"), timeZoneIdentifier: "UTC")
        let fromComponents = try calculator.localDay(year: 2026, month: 1, day: 3, timeZoneIdentifier: "UTC")

        XCTAssertEqual(fromInstant.canonicalKey, "2026-01-03")
        XCTAssertEqual(fromComponents.canonicalKey, "2026-01-03")
        XCTAssertNotEqual(fromInstant.canonicalKey, "2026-1-3")
    }

    // MARK: C3 — one instant, two scheduling time zones

    func testC3SameInstantBelongsToDifferentCivilDaysInLosAngelesAndTokyo() throws {
        let moment = instant("2026-09-28T05:30:00Z") // 22:30 Sep 27 in Los Angeles, 14:30 Sep 28 in Tokyo

        let losAngeles = try calculator.localDay(containing: moment, timeZoneIdentifier: "America/Los_Angeles")
        let tokyo = try calculator.localDay(containing: moment, timeZoneIdentifier: "Asia/Tokyo")

        XCTAssertEqual(losAngeles.canonicalKey, "2026-09-27")
        XCTAssertEqual(tokyo.canonicalKey, "2026-09-28")
        XCTAssertTrue(losAngeles.contains(moment))
        XCTAssertTrue(tokyo.contains(moment))
        XCTAssertEqual(losAngeles.timeZoneIdentifier, "America/Los_Angeles")
        XCTAssertEqual(tokyo.timeZoneIdentifier, "Asia/Tokyo")
    }

    // MARK: C4–C5 — half-open membership

    func testC4StartBelongsAndEndBelongsToTheNextDay() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertTrue(day.contains(day.start))
        XCTAssertFalse(day.contains(day.end))
        let next = try calculator.localDay(containing: day.end, timeZoneIdentifier: "America/Los_Angeles")
        XCTAssertEqual(next.canonicalKey, "2026-09-29")
        XCTAssertEqual(next.start, day.end)
    }

    func testC5InstantJustBeforeEndBelongsAndJustBeforeStartDoesNot() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertTrue(day.contains(day.end.addingTimeInterval(-0.001)))
        XCTAssertFalse(day.contains(day.start.addingTimeInterval(-0.001)))
        let lastMoment = try calculator.localDay(containing: day.end.addingTimeInterval(-0.001),
                                                 timeZoneIdentifier: "America/Los_Angeles")
        XCTAssertEqual(lastMoment, day)
    }

    // MARK: C6–C8 — daylight saving time comes from the calendar, not fixed seconds

    func testC6SpringForwardDayInLosAngelesIs23Hours() throws {
        let day = try calculator.localDay(year: 2026, month: 3, day: 8, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(day.canonicalKey, "2026-03-08")
        XCTAssertEqual(day.start, instant("2026-03-08T08:00:00Z")) // 00:00 PST
        XCTAssertEqual(day.end, instant("2026-03-09T07:00:00Z"))   // 00:00 PDT
        XCTAssertLessThan(day.start, day.end)
        XCTAssertEqual(day.duration, 23 * 3_600)
        // Both sides of the skipped hour (01:59 PST, then 03:00 PDT) belong to the same civil day.
        XCTAssertTrue(day.contains(instant("2026-03-08T09:59:00Z")))
        XCTAssertTrue(day.contains(instant("2026-03-08T10:00:00Z")))
    }

    func testC7FallBackDayInLosAngelesIs25Hours() throws {
        let day = try calculator.localDay(year: 2026, month: 11, day: 1, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(day.canonicalKey, "2026-11-01")
        XCTAssertEqual(day.start, instant("2026-11-01T07:00:00Z")) // 00:00 PDT
        XCTAssertEqual(day.end, instant("2026-11-02T08:00:00Z"))   // 00:00 PST
        XCTAssertLessThan(day.start, day.end)
        XCTAssertEqual(day.duration, 25 * 3_600)
        // The repeated 01:30 (first PDT, then PST) is the same civil day either way.
        for repeated in [instant("2026-11-01T08:30:00Z"), instant("2026-11-01T09:30:00Z")] {
            let containing = try calculator.localDay(containing: repeated, timeZoneIdentifier: "America/Los_Angeles")
            XCTAssertEqual(containing, day)
        }
    }

    func testC8NormalLosAngelesDayIs24Hours() throws {
        let day = try calculator.localDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(day.start, instant("2026-09-28T07:00:00Z"))
        XCTAssertEqual(day.end, instant("2026-09-29T07:00:00Z"))
        XCTAssertEqual(day.duration, 24 * 3_600)
    }

    // MARK: C9–C12 — year boundary, leap day, strict component validation

    func testC9YearBoundaryNextDayIsJanuaryFirst() throws {
        let newYearsEve = try calculator.localDay(year: 2026, month: 12, day: 31, timeZoneIdentifier: "America/Los_Angeles")
        let next = try calculator.localDay(containing: newYearsEve.end, timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(newYearsEve.canonicalKey, "2026-12-31")
        XCTAssertEqual(next.canonicalKey, "2027-01-01")
        XCTAssertEqual(next.start, newYearsEve.end)
    }

    func testC10LeapDayIsValid() throws {
        let leapDay = try calculator.localDay(year: 2028, month: 2, day: 29, timeZoneIdentifier: "UTC")
        let next = try calculator.localDay(containing: leapDay.end, timeZoneIdentifier: "UTC")

        XCTAssertEqual(leapDay.canonicalKey, "2028-02-29")
        XCTAssertEqual(next.canonicalKey, "2028-03-01")
    }

    func testC11February29InANonLeapYearIsRejectedNotNormalized() {
        XCTAssertThrowsError(try calculator.localDay(year: 2026, month: 2, day: 29, timeZoneIdentifier: "UTC")) { error in
            XCTAssertEqual(error as? LocalDayError, .invalidGregorianDate(year: 2026, month: 2, day: 29))
        }
    }

    func testC12ImpossibleDatesAreRejected() {
        // The last two are outside 1583...9999: a Julian-only leap day and a day of the 1582 calendar switch.
        let impossible: [(Int, Int, Int)] = [(2026, 4, 31), (2026, 2, 30), (2026, 13, 1), (2026, 0, 10),
                                             (2026, 6, 0), (2026, 6, 32), (0, 1, 1), (10_000, 1, 1),
                                             (1500, 2, 29), (1582, 10, 10)]
        for (year, month, day) in impossible {
            XCTAssertThrowsError(try calculator.localDay(year: year, month: month, day: day,
                                                         timeZoneIdentifier: "America/Los_Angeles")) { error in
                XCTAssertEqual(error as? LocalDayError, .invalidGregorianDate(year: year, month: month, day: day))
            }
        }
        XCTAssertEqual(try calculator.localDay(year: 1583, month: 1, day: 1, timeZoneIdentifier: "UTC").canonicalKey, "1583-01-01")
    }

    // MARK: C13 — no hidden time zone fallback

    func testC13InvalidTimeZoneIdentifierIsATypedErrorWithoutFallback() {
        for identifier in ["Mars/Olympus_Mons", "", "Not A Zone"] {
            XCTAssertThrowsError(try calculator.localDay(containing: instant("2026-09-28T12:00:00Z"),
                                                         timeZoneIdentifier: identifier)) { error in
                XCTAssertEqual(error as? LocalDayError, .invalidTimeZoneIdentifier(identifier))
            }
            XCTAssertThrowsError(try calculator.localDay(year: 2026, month: 9, day: 28,
                                                         timeZoneIdentifier: identifier)) { error in
                XCTAssertEqual(error as? LocalDayError, .invalidTimeZoneIdentifier(identifier))
            }
        }
    }

    func testNonFiniteInstantIsATypedError() {
        let impossible = Date(timeIntervalSinceReferenceDate: .infinity)
        XCTAssertThrowsError(try calculator.localDay(containing: impossible, timeZoneIdentifier: "UTC")) { error in
            guard case .unrepresentableInstant? = error as? LocalDayError else {
                return XCTFail("Expected unrepresentableInstant, got \(error)")
            }
        }
    }

    // MARK: C14–C16 — deterministic, locale-free, always Gregorian

    func testC14FreshCalculatorsAndBothEntryPointsProduceIdenticalDays() throws {
        let moment = instant("2026-09-28T18:00:00Z")
        let first = try GregorianLocalDayCalculator().localDay(containing: moment, timeZoneIdentifier: "America/Los_Angeles")
        let second = try GregorianLocalDayCalculator().localDay(containing: moment, timeZoneIdentifier: "America/Los_Angeles")
        let fromComponents = try GregorianLocalDayCalculator().localDay(year: 2026, month: 9, day: 28,
                                                                        timeZoneIdentifier: "America/Los_Angeles")

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, fromComponents)
    }

    func testC15CanonicalKeyIsASCIIDigitsAndHyphensOnly() throws {
        let days = [
            try calculator.localDay(year: 2026, month: 1, day: 3, timeZoneIdentifier: "Asia/Tokyo"),
            try calculator.localDay(year: 2028, month: 2, day: 29, timeZoneIdentifier: "America/Los_Angeles"),
            try calculator.localDay(year: 2026, month: 12, day: 31, timeZoneIdentifier: "UTC"),
        ]
        let allowed = Set("0123456789-")
        for day in days {
            XCTAssertEqual(day.canonicalKey.count, 10)
            XCTAssertTrue(day.canonicalKey.allSatisfy { allowed.contains($0) }, day.canonicalKey)
        }
        XCTAssertEqual(days.map(\.canonicalKey), ["2026-01-03", "2028-02-29", "2026-12-31"])
    }

    func testC16ResultIsGregorianWhateverOtherCalendarsSay() throws {
        let moment = instant("2026-09-28T12:00:00Z")
        let day = try calculator.localDay(containing: moment, timeZoneIdentifier: "UTC")

        // The same instant in non-Gregorian calendars has different year numbers; the key does not.
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "UTC")!
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(buddhist.component(.year, from: moment), 2569)
        XCTAssertEqual(japanese.component(.year, from: moment), 8)
        XCTAssertEqual(day.year, 2026)
        XCTAssertEqual(day.canonicalKey, "2026-09-28")
    }

    // MARK: - Helpers

    private func instant(_ iso8601: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: iso8601) else {
            preconditionFailure("Bad test fixture \(iso8601)")
        }
        return date
    }
}
