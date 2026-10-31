//
//  MenuBarPresentationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

struct MenuBarPresentationTests {

    // MARK: - Public Methods

    /// The size next to the icon: nothing until the first measurement, then the estimated total.
    @Test
    func theLabelShowsTheSizeOnlyWhenItIsKnown() {
        #expect(MenuBarPresentation.label(phase: .measuring(first: true), totalBytes: 0, showsSize: true) == nil)
        #expect(MenuBarPresentation.label(phase: .ready, totalBytes: 5_000, showsSize: false) == nil)
        #expect(MenuBarPresentation.label(phase: .ready, totalBytes: 5_000, showsSize: true) == .size(5_000))
        #expect(MenuBarPresentation
            .label(phase: .measuring(first: false), totalBytes: 5_000, showsSize: true) == .size(5_000))
        #expect(MenuBarPresentation.label(phase: .cancelling, totalBytes: 5_000, showsSize: true) == .cleaning)
        #expect(
            MenuBarPresentation.label(
                phase: .cleaning(CleanupProgress(totalCategories: 1)),
                totalBytes: 5_000,
                showsSize: true
            ) == .cleaning
        )
    }

    /// Nothing starts a cleanup while simulators or a runtime are being deleted (C21).
    @Test
    func cleaningAndRetryingWaitForASimulatorDeletion() {
        #expect(!MenuBarPresentation.isEnabled(.clean, isDeletingSimulators: true))
        #expect(!MenuBarPresentation.isEnabled(.retry, isDeletingSimulators: true))
        #expect(MenuBarPresentation.isEnabled(.cancel, isDeletingSimulators: true))
        #expect(MenuBarPresentation.isEnabled(.dismiss, isDeletingSimulators: true))
        #expect(MenuBarPresentation.isEnabled(.clean, isDeletingSimulators: false))
    }

    /// A plan waiting for a confirmation needs the main window, which shows it.
    @Test
    func aPendingConfirmationOpensTheMainWindow() {
        #expect(MenuBarPresentation.needsMainWindow(after: .confirming(CleanupPlan(categories: []))))
        #expect(!MenuBarPresentation.needsMainWindow(after: .ready))
        #expect(!MenuBarPresentation.needsMainWindow(after: .cleaning(CleanupProgress(totalCategories: 1))))
    }

    /// With Settings, closing the last window quits only when the menu bar item is off (R14).
    @Test
    func closingTheLastWindowQuitsOnlyWithoutTheMenuBarItem() {
        #expect(MenuBarPresentation.quitsAfterLastWindowClosed(showsMenuBarExtra: false))
        #expect(!MenuBarPresentation.quitsAfterLastWindowClosed(showsMenuBarExtra: true))
    }

}
