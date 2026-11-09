//
//  CleanerWindowSheetTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Testing
@testable import CleanerXcode

/// The window's only sheet: the cleanup confirmation, or "Support CleanerXcode" (C31).
struct CleanerWindowSheetTests {

    // MARK: - Public Methods

    /// A confirmation always wins: the support sheet never covers it.
    @Test
    func aConfirmationShowsItsSheet() {
        let confirming = CleanerPhase.confirming(CleanupPlan(categories: []))

        #expect(CleanerWindowSheet.resolve(phase: confirming, isShowingSupportSheet: false) == .confirmation)
        #expect(CleanerWindowSheet.resolve(phase: confirming, isShowingSupportSheet: true) == .confirmation)
    }

    @Test
    func theSupportSheetShowsWhenAsked() {
        let success = CleanerPhase.finished(CleanupReport(results: []))

        #expect(CleanerWindowSheet.resolve(phase: success, isShowingSupportSheet: true) == .support)
        #expect(CleanerWindowSheet.resolve(phase: .ready, isShowingSupportSheet: true) == .support)
    }

    @Test
    func otherwiseThereIsNoSheet() {
        for phase: CleanerPhase in [.ready, .finished(CleanupReport(results: [])), .measuring(first: false)] {
            #expect(CleanerWindowSheet.resolve(phase: phase, isShowingSupportSheet: false) == nil, "\(phase)")
        }
    }

    @Test
    func eachSheetHasItsOwnIdentity() {
        #expect(CleanerWindowSheet.confirmation.id != CleanerWindowSheet.support.id)
    }

}
