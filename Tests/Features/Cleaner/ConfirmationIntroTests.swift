//
//  ConfirmationIntroTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

/// The first sentence of the confirmation names the kinds of risk it lists (Figma, sheet 7:119).
struct ConfirmationIntroTests {

    // MARK: - Public Methods

    @Test
    func namesTheRisksOfTheListedItems() {
        #expect(ConfirmationIntro(risks: [.attention, .dangerous, .safe]) == .attentionAndDangerous)
        #expect(ConfirmationIntro(risks: [.attention]) == .attention)
        #expect(ConfirmationIntro(risks: [.dangerous, .dangerous]) == .dangerous)
        #expect(ConfirmationIntro(risks: [.safe]) == .appsOpen, "Only an open app asks.")
        #expect(ConfirmationIntro(risks: []) == .appsOpen)
    }

}
