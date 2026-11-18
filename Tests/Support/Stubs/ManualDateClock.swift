//
//  ManualDateClock.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// A wall clock that only moves when the test says, injected as `now: { clock.now }`.
final class ManualDateClock {

    // MARK: - Public Properties

    private(set) var now: Date

    // MARK: - Initializers

    init(now: Date = Date(timeIntervalSince1970: 100_000)) {
        self.now = now
    }

    // MARK: - Public Methods

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

}
