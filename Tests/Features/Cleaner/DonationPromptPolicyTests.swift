//
//  DonationPromptPolicyTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Testing
@testable import CleanerXcode

/// When the success suggests a donation (C31): on every fifth successful cleanup, never before the
/// first one.
struct DonationPromptPolicyTests {

    // MARK: - Public Methods

    @Test
    func theIntervalIsFiveCleanups() {
        #expect(DonationPromptPolicy().interval == 5)
    }

    @Test(arguments: [5, 10, 15, 100])
    func everyMultipleOfTheIntervalSuggestsADonation(count: Int) {
        #expect(DonationPromptPolicy().shouldPrompt(afterSuccessfulCleanups: count))
    }

    @Test(arguments: [0, 1, 2, 3, 4, 6, 9, 11, -5])
    func theOtherCountsDoNot(count: Int) {
        #expect(!DonationPromptPolicy().shouldPrompt(afterSuccessfulCleanups: count))
    }

}
