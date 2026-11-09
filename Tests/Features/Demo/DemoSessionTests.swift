//
//  DemoSessionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Testing
@testable import CleanerXcode

struct DemoSessionTests {

    // MARK: - Public Methods

    /// Closing and reopening the window must not play the tour again over a cleaned state.
    @Test
    func tourIsClaimedOnce() {
        var claims = DemoSession.RunClaim()

        let first = claims.claim()
        let second = claims.claim()

        #expect(first)
        #expect(second == false)
    }

}
