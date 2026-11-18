//
//  MenuBarPresentationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
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
        #expect(MenuBarPresentation
            .label(phase: .cancelling(freedBytes: 0), totalBytes: 5_000, showsSize: true) == .cleaning)
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

    /// The panel is shorter than the window: "Cleaning · 3 of 5", and no detail under a total
    /// that is just waiting to be cleaned (Figma page 05).
    @Test
    func thePanelShortensWhatTheWindowSpellsOut() {
        let progress = CleanupProgress(totalCategories: 5, startedCategories: 3)

        #expect(MenuBarPresentation.eyebrow(phase: .cleaning(progress))?.key == "Cleaning · %lld of %lld")
        #expect(MenuBarPresentation.eyebrow(phase: .ready) == nil)
        #expect(!MenuBarPresentation.showsDetail(phase: .ready, detail: .content))
        #expect(MenuBarPresentation.showsDetail(phase: .ready, detail: .reviewInWindow))
        #expect(MenuBarPresentation.showsDetail(phase: .cleaning(progress), detail: .content))
    }

    /// With failures to look at, the link under the action becomes "See details".
    @Test
    func theLinkOffersTheDetailsOfAFailedRun() {
        #expect(MenuBarPresentation.link(for: [.retry, .toggleDetails]) == .seeDetails)
        #expect(MenuBarPresentation.link(for: [.clean]) == .openApp)
    }

    /// The panel names the risk it will confirm, never "dangerous" for an attention-only plan or
    /// one that only waits for an open app.
    @Test
    func theReviewNoteNamesTheRiskOfThePlan() {
        #expect(MenuBarPresentation.ReviewNote(risks: [.attention, .dangerous]) == .dangerous)
        #expect(MenuBarPresentation.ReviewNote(risks: [.safe, .attention]) == .attention)
        #expect(MenuBarPresentation.ReviewNote(risks: [.safe]) == .appsOpen)
        #expect(MenuBarPresentation.ReviewNote(risks: []) == .appsOpen)
    }

    /// "Support the project" never waits for a simulator deletion, and it opens the main window,
    /// which shows the sheet (C31); the failures' details also open it.
    @Test
    func supportingTheProjectOpensTheMainWindow() {
        #expect(MenuBarPresentation.isEnabled(.supportProject, isDeletingSimulators: true))
        #expect(MenuBarPresentation.opensMainWindow(for: .supportProject))
        #expect(MenuBarPresentation.opensMainWindow(for: .toggleDetails))

        for kind: HeroContent.Action.Kind in [.clean, .cancel, .dismiss, .retry, .openPrivacySettings] {
            #expect(!MenuBarPresentation.opensMainWindow(for: kind), "\(kind)")
        }

        #expect(MenuBarPresentation.link(for: [.supportProject, .dismiss]) == .openApp)
    }

    /// "Close" goes under the main action as text only when it is a plain action (C31).
    @Test
    func onlyAPlainSecondActionShowsUnderTheMainOne() {
        let suggestion = [
            HeroContent.Action(.supportProject, "Support the project", style: .support),
            HeroContent.Action(.dismiss, "Close", style: .plain),
        ]
        let partial = [
            HeroContent.Action(.retry, "Try again"),
            HeroContent.Action(.toggleDetails, "See details", style: .secondary),
        ]

        #expect(MenuBarPresentation.textAction(in: suggestion)?.kind == .dismiss)
        #expect(MenuBarPresentation.textAction(in: partial) == nil)
        #expect(MenuBarPresentation.textAction(in: [suggestion[1]]) == nil, "Never the main action itself.")
    }

    /// A failed run or a permission denial both offer their details from the panel.
    @Test
    func aPermissionDenialAlsoOffersItsDetails() {
        #expect(MenuBarPresentation.link(for: [.openPrivacySettings, .retry]) == .seeDetails)
    }

}
