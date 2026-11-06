//
//  BackgroundMeasurementPolicyTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// When the menu bar icon measures in the background (C40): each rule, and the order among them.
struct BackgroundMeasurementPolicyTests {

    // MARK: - Private Properties

    private let policy = BackgroundMeasurementPolicy()
    private let now = Date(timeIntervalSince1970: 100_000)

    // MARK: - Public Methods

    @Test
    func theDefaultsAreThirtyMinutesWithALaunchDelay() {
        #expect(policy.interval == .seconds(1_800))
        #expect(policy.launchDelay == .seconds(30))
        #expect(policy.wakeDelay == .seconds(120))
        #expect(policy.retryDelay == .seconds(120))
        #expect(policy.minimumWait == .seconds(60))
        #expect(policy.tolerance == .seconds(60))
    }

    @Test
    func turnedOffItWaitsAWholeIntervalEvenWhenBusy() {
        #expect(decision(isEnabled: false, isBusy: true) == .wait(.seconds(1_800)))
        #expect(decision(isLaunch: true, isEnabled: false) == .wait(.seconds(1_800)))
    }

    @Test
    func whileSimulatorsAreDeletedItTriesAgainSoon() {
        #expect(decision(isBusy: true) == .wait(.seconds(120)))
        #expect(decision(isBusy: true, isConstrained: true) == .wait(.seconds(120)))
    }

    @Test
    func lowPowerOrAHotMacSkipsThePeriodicMeasurementButNotTheLaunchOne() {
        #expect(decision(isConstrained: true) == .wait(.seconds(1_800)))
        #expect(decision(isLaunch: true, isConstrained: true) == .measure)
    }

    @Test
    func aRecentMeasurementPostponesTheNextOne() {
        #expect(decision(age: .seconds(600)) == .wait(.seconds(1_200)))
        #expect(decision(isLaunch: true, age: .seconds(600)) == .wait(.seconds(1_200)))
        #expect(decision(age: .seconds(1_770)) == .wait(.seconds(60)), "Never sooner than the minimum wait.")
    }

    @Test
    func anOldMeasurementOrNoneAtAllMeasures() {
        #expect(decision() == .measure)
        #expect(decision(age: .seconds(1_800)) == .measure)
        #expect(decision(age: .seconds(7_200)) == .measure)
    }

    /// A clock moved back never makes it wait longer than an interval.
    @Test
    func aMeasurementInTheFutureWaitsOneInterval() {
        #expect(decision(age: .seconds(-300)) == .wait(.seconds(1_800)))
    }

    // MARK: - Private Methods

    private func decision(
        isLaunch: Bool = false,
        isEnabled: Bool = true,
        isBusy: Bool = false,
        isConstrained: Bool = false,
        age: Duration? = nil
    ) -> BackgroundMeasurementPolicy.Decision {
        let lastMeasuredAt = age.map { now.addingTimeInterval(-Double($0.components.seconds)) }

        return policy.decision(
            isLaunch: isLaunch,
            isEnabled: isEnabled,
            isBusy: isBusy,
            isConstrained: isConstrained,
            age: BackgroundMeasurementPolicy.age(since: lastMeasuredAt, now: now)
        )
    }

}
