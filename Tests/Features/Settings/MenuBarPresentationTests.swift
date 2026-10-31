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

    /// The panel explains a disabled Clean or retry during a simulator deletion; otherwise it asks
    /// for the window when the plan needs a confirmation, or shows the usual detail.
    @Test
    func picksThePanelDetail() {
        #expect(MenuBarPresentation.panelDetail(
            action: .clean,
            isEnabled: true,
            isDeletingSimulators: true,
            reviewsInWindow: true
        ) == .waitForSimulators)
        #expect(MenuBarPresentation.panelDetail(
            action: .retry,
            isEnabled: true,
            isDeletingSimulators: true,
            reviewsInWindow: false
        ) == .waitForSimulators)
        #expect(MenuBarPresentation.panelDetail(
            action: .dismiss,
            isEnabled: true,
            isDeletingSimulators: true,
            reviewsInWindow: false
        ) == .content)
        #expect(
            MenuBarPresentation
                .panelDetail(action: .clean, isEnabled: false, isDeletingSimulators: true, reviewsInWindow: false) ==
                .content,
            "Already disabled for another reason."
        )
        #expect(MenuBarPresentation.panelDetail(
            action: .clean,
            isEnabled: true,
            isDeletingSimulators: false,
            reviewsInWindow: true
        ) == .reviewInWindow)
        #expect(MenuBarPresentation.panelDetail(
            action: .clean,
            isEnabled: true,
            isDeletingSimulators: false,
            reviewsInWindow: false
        ) == .content)
        #expect(MenuBarPresentation.panelDetail(
            action: nil,
            isEnabled: false,
            isDeletingSimulators: true,
            reviewsInWindow: false
        ) == .content)
    }

}
