//
//  LocalDayCalculating.swift
//  HabitHonker
//

import Foundation

/// Maps instants and civil dates to Gregorian civil days in an explicit scheduling time zone.
/// The scheduling time zone is always an input; nothing is taken from the device.
protocol LocalDayCalculating: Sendable {
    /// The civil day that contains `date` in the named time zone.
    /// Throws `LocalDayError.invalidTimeZoneIdentifier` or `.unrepresentableInstant`.
    func localDay(containing date: Date, timeZoneIdentifier: String) throws -> LocalDay

    /// The civil day with exactly these Gregorian components. Impossible dates are rejected,
    /// never normalized. Throws `LocalDayError.invalidGregorianDate` or `.invalidTimeZoneIdentifier`.
    func localDay(year: Int, month: Int, day: Int, timeZoneIdentifier: String) throws -> LocalDay
}
