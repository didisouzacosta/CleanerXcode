//
//  RuntimeDownloadRemainingTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The estimated time left, rounded the friendly way (C34). The number shown is never exactly
/// "1 min" nor "1 h", so "Cerca de … restantes" never needs a singular.
struct RuntimeDownloadRemainingTests {

    // MARK: - Public Methods

    @Test(arguments: [
        (0, RuntimeDownloadRemaining.lessThanAMinute),
        (59, .lessThanAMinute),
        (60, .minutes(2)),
        (61, .minutes(2)),
        (719, .minutes(12)),
        (3_599, .minutes(60)),
        (3_600, .minutes(60)),
        (4_800, .hoursAndMinutes(totalMinutes: 80)),
        (4_949, .hoursAndMinutes(totalMinutes: 80)),
        (7_200, .hoursAndMinutes(totalMinutes: 120)),
    ])
    func roundsTheSecondsLeft(seconds: Int, remaining: RuntimeDownloadRemaining) {
        #expect(RuntimeDownloadRemaining(rounding: .seconds(seconds)) == remaining)
    }

    @Test
    func aNegativeDurationHasNoEstimate() {
        #expect(RuntimeDownloadRemaining(rounding: .seconds(-1)) == nil)
    }

    @Test
    func theTextUsesTheLocalizedDurationFormat() {
        let twelve = Duration.seconds(12 * 60).formatted(.units(allowed: [.minutes], width: .abbreviated))
        let eighty = Duration.seconds(80 * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))

        #expect(RuntimeDownloadRemaining.lessThanAMinute.text == String(localized: "Less than 1 min left"))
        #expect(RuntimeDownloadRemaining.minutes(12).text == String(localized: "About \(twelve) left"))
        #expect(RuntimeDownloadRemaining.hoursAndMinutes(totalMinutes: 80)
            .text == String(localized: "About \(eighty) left"))
    }

    /// Guards the text drawn in the Figma frames.
    @Test
    func thePortugueseDurationKeepsTheHoursAndMinutes() {
        let style = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .abbreviated)
            .locale(Locale(identifier: "pt_BR"))
        let text = Duration.seconds(4_800).formatted(style)

        #expect(text.contains("1"))
        #expect(text.contains("20"))
    }

}
