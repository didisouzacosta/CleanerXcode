//
//  ManualClock.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

/// A clock that only moves when the test says, injected as `now: { clock.now }`.
final class ManualClock {

    // MARK: - Public Properties

    private(set) var now = ContinuousClock.now

    // MARK: - Public Methods

    func advance(by duration: Duration) {
        now += duration
    }

}
