//
//  BackgroundMeasurementPolicy.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// When the menu bar icon measures in the background (C40). The native measurement walks
/// DerivedData, CoreSimulator and the like, which grow over builds and hours, so it runs every
/// 30 minutes; the window and the panel already measure when they open.
nonisolated struct BackgroundMeasurementPolicy: Equatable, Sendable {

    // MARK: - Public Properties

    var interval: Duration = .seconds(1_800)
    /// Keeps the launch measurement away from the login and the app's own start.
    var launchDelay: Duration = .seconds(30)
    var wakeDelay: Duration = .seconds(120)
    /// While simulators or a runtime are being deleted; the deletion measures when it ends.
    var retryDelay: Duration = .seconds(120)
    var minimumWait: Duration = .seconds(60)
    /// Lets the system coalesce the wake-ups.
    var tolerance: Duration = .seconds(60)

    // MARK: - Public Methods

    /// The time since `lastMeasuredAt`, for `decision`.
    static func age(since lastMeasuredAt: Date?, now: Date) -> Duration? {
        lastMeasuredAt.map { Duration.seconds(now.timeIntervalSince($0)) }
    }

    /// The rules, in order: turned off, busy, constrained (except at launch), a recent
    /// measurement, then measure. `age` is the time since the last complete measurement, `nil`
    /// when there was none.
    func decision(isLaunch: Bool, isEnabled: Bool, isBusy: Bool, isConstrained: Bool, age: Duration?) -> Decision {
        guard isEnabled else { return .wait(interval) }

        guard !isBusy else { return .wait(retryDelay) }

        guard isLaunch || !isConstrained else { return .wait(interval) }

        guard let age else { return .measure }

        // A clock moved back counts as a measurement that just ended.
        let elapsed = max(age, .zero)

        guard elapsed >= interval else { return .wait(max(interval - elapsed, minimumWait)) }

        return .measure
    }

    // MARK: - Nested Types

    enum Decision: Equatable, Sendable {
        case measure
        case wait(Duration)
    }

}
