//
//  LocalDay.swift
//  HabitHonker
//

import Foundation

/// A Gregorian civil day in an explicit scheduling time zone, with exact half-open bounds
/// `[start, end)`.
///
/// Values are created only by `GregorianLocalDayCalculator` (below, which is why it lives in this
/// file), so every `LocalDay` names a real Gregorian date and carries boundaries computed by
/// calendar arithmetic. The device's own calendar, time zone and locale never take part.
struct LocalDay: Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int
    /// The explicit scheduling time zone the day was computed in, exactly as supplied.
    let timeZoneIdentifier: String
    /// First instant of the day. Inclusive.
    let start: Date
    /// First instant of the next civil day. Exclusive. 23, 24 or 25 hours after `start`.
    let end: Date

    fileprivate init(year: Int, month: Int, day: Int, timeZoneIdentifier: String, start: Date, end: Date) {
        self.year = year
        self.month = month
        self.day = day
        self.timeZoneIdentifier = timeZoneIdentifier
        self.start = start
        self.end = end
    }

    /// Canonical `YYYY-MM-DD`: zero-padded ASCII digits, never localized. Part of logical identity.
    var canonicalKey: String {
        "\(Self.zeroPadded(year, width: 4))-\(Self.zeroPadded(month, width: 2))-\(Self.zeroPadded(day, width: 2))"
    }

    /// Half-open membership, stated explicitly: `start <= date` and `date < end`.
    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    /// Convenience only; business membership is `contains(_:)`.
    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    /// The real length of this civil day; daylight-saving days are shorter or longer.
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    private static func zeroPadded(_ value: Int, width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}

/// Why a civil day could not be determined. There is never a silent fallback.
enum LocalDayError: Error, Equatable, Sendable {
    /// Not a time zone identifier the system knows. No fallback zone (UTC, GMT or the device's) is used.
    case invalidTimeZoneIdentifier(String)
    /// Not a real Gregorian date in the supported years 1583...9999, for example 2026-02-29 or 2026-04-31.
    /// Such dates are rejected, never normalized to a neighboring day.
    case invalidGregorianDate(year: Int, month: Int, day: Int)
    /// A non-finite instant, or one whose civil date lies outside the supported years 1583...9999.
    case unrepresentableInstant(Date)
}

/// V1 scheduling calendar: Gregorian, in an explicitly supplied time zone.
struct GregorianLocalDayCalculator: LocalDayCalculating {
    /// Foundation's Gregorian calendar is Julian before 15 October 1582, so earlier years would not be
    /// Gregorian dates. Four-digit years keep every canonical key in the fixed `YYYY-MM-DD` shape.
    static let supportedYears = 1583...9999

    init() {}

    func localDay(containing date: Date, timeZoneIdentifier: String) throws -> LocalDay {
        let calendar = try Self.gregorianCalendar(timeZoneIdentifier: timeZoneIdentifier)
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw LocalDayError.unrepresentableInstant(date)
        }
        let parts = calendar.dateComponents([.era, .year, .month, .day], from: date)
        guard parts.era == 1,
              let year = parts.year, let month = parts.month, let day = parts.day,
              let localDay = Self.makeDay(year: year, month: month, day: day,
                                          calendar: calendar, timeZoneIdentifier: timeZoneIdentifier),
              localDay.contains(date) else {
            throw LocalDayError.unrepresentableInstant(date)
        }
        return localDay
    }

    func localDay(year: Int, month: Int, day: Int, timeZoneIdentifier: String) throws -> LocalDay {
        let calendar = try Self.gregorianCalendar(timeZoneIdentifier: timeZoneIdentifier)
        guard let localDay = Self.makeDay(year: year, month: month, day: day,
                                          calendar: calendar, timeZoneIdentifier: timeZoneIdentifier) else {
            throw LocalDayError.invalidGregorianDate(year: year, month: month, day: day)
        }
        return localDay
    }

    /// Always an explicitly constructed Gregorian calendar in the requested zone.
    private static func gregorianCalendar(timeZoneIdentifier: String) throws -> Calendar {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw LocalDayError.invalidTimeZoneIdentifier(timeZoneIdentifier)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// The day with exactly these components, or nil if they do not name a real supported date.
    private static func makeDay(year: Int, month: Int, day: Int,
                                calendar: Calendar, timeZoneIdentifier: String) -> LocalDay? {
        guard supportedYears.contains(year), (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        // Strict validation: a calendar would quietly turn February 30 into March 2,
        // so the resolved date must read back as exactly the requested components.
        guard let anchor = calendar.date(from: DateComponents(era: 1, year: year, month: month, day: day)) else {
            return nil
        }
        let resolved = calendar.dateComponents([.era, .year, .month, .day], from: anchor)
        guard resolved.era == 1, resolved.year == year, resolved.month == month, resolved.day == day else {
            return nil
        }
        // [start, end): end is the start of the NEXT civil day, found by calendar arithmetic,
        // never by adding a fixed number of seconds. This yields 23/25-hour daylight-saving days.
        let start = calendar.startOfDay(for: anchor)
        guard let nextDayAnchor = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        let end = calendar.startOfDay(for: nextDayAnchor)
        guard end > start else {
            return nil
        }
        return LocalDay(year: year, month: month, day: day,
                        timeZoneIdentifier: timeZoneIdentifier, start: start, end: end)
    }
}
