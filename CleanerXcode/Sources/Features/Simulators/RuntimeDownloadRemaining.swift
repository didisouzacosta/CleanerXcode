//
//  RuntimeDownloadRemaining.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation

/// The estimated time left of a runtime download, rounded the friendly way (C34). The number shown
/// is never exactly 1 minute nor 1 hour, so "Cerca de … restantes" never needs a singular.
enum RuntimeDownloadRemaining: Equatable {

    // MARK: - Cases

    case lessThanAMinute
    /// From 2 to 60.
    case minutes(Int)
    /// From 65, always a multiple of 5.
    case hoursAndMinutes(totalMinutes: Int)

    // MARK: - Public Properties

    /// "About 12 min left", "About 1 hr, 20 min left", with the locale's duration format.
    var text: String {
        switch self {
        case .lessThanAMinute:
            String(localized: "Less than 1 min left")

        case let .minutes(minutes):
            Self.about(minutes, allowed: [.minutes])

        case let .hoursAndMinutes(totalMinutes):
            Self.about(totalMinutes, allowed: [.hours, .minutes])
        }
    }

    // MARK: - Initializers

    /// Under a minute; then whole minutes rounded up (at least 2); from an hour, the nearest
    /// 5 minutes. `nil` for a negative duration.
    init?(rounding duration: Duration) {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18

        guard seconds >= 0 else { return nil }

        guard seconds >= 60 else {
            self = .lessThanAMinute
            return
        }

        guard seconds >= 3_600 else {
            self = .minutes(max(2, Int((seconds / 60).rounded(.up))))
            return
        }

        let minutes = Int((seconds / 300).rounded()) * 5

        self = minutes == 60 ? .minutes(60) : .hoursAndMinutes(totalMinutes: minutes)
    }

    // MARK: - Private Methods

    private static func about(_ minutes: Int, allowed units: Set<Duration.UnitsFormatStyle.Unit>) -> String {
        let duration = Duration.seconds(minutes * 60).formatted(.units(allowed: units, width: .abbreviated))

        return String(localized: "About \(duration) left")
    }

}
