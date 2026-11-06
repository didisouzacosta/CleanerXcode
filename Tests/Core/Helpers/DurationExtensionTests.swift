//
//  DurationExtensionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Testing
@testable import CleanerXcode

/// A `Duration` in seconds, for the FSEvents latency and the live measurement's dates.
struct DurationExtensionTests {

    // MARK: - Public Methods

    @Test
    func wholeSecondsKeepTheirValue() {
        #expect(Duration.seconds(2).timeInterval == 2)
        #expect(Duration.zero.timeInterval == 0)
    }

    @Test
    func fractionsOfASecondAreKept() {
        #expect(Duration.milliseconds(1_500).timeInterval == 1.5)
        #expect(Duration.milliseconds(100).timeInterval == 0.1)
    }

}
