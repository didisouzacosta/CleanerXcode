//
//  ActionBarContentTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The fixed action bar of the window (Figma page 08), adapted from the hero of each phase: the
/// main action always comes last, and only Cancel and OK have keyboard shortcuts (R39).
struct ActionBarContentTests {

    // MARK: - Public Methods

    @Test
    func theFirstMeasurementShowsADash() {
        let bar = content(.measuring(first: true))

        #expect(bar.eyebrow.key == "Calculating the space…")
        #expect(bar.amount == "—")
        #expect(bar.isAmountDimmed)
        #expect(bar.suffix == nil)
        #expect(bar.progress == nil)
        #expect(bar.actions.map(\.kind) == [.clean])
        #expect(!bar.actions[0].isEnabled)
    }

    @Test
    func readyOffersTheEstimatedTotal() {
        let hero = hero(.ready, totalBytes: 5_000)
        let bar = ActionBarContent(hero: hero, phase: .ready, isShowingDetails: false)

        #expect(bar.eyebrow.key == hero.eyebrow.key)
        #expect(bar.amount == hero.amount)
        #expect(bar.suffix == .estimated)
        #expect(bar.progress == nil)
        #expect(bar.symbol == nil)
        #expect(bar.actions.map(\.kind) == [.clean])
        #expect(bar.actions[0].isEnabled)
    }

    /// Clean waits during a confirmation, while measuring and with nothing to do.
    @Test
    func cleanIsDisabledWhenThereIsNothingToStart() {
        for phase: CleanerPhase in [
            .confirming(CleanupPlan(categories: [])),
            .measuring(first: true),
            .measuring(first: false),
            .nothingSelected,
            .nothingToClean,
        ] {
            let bar = content(phase, totalBytes: 5_000)

            #expect(bar.actions.map(\.kind) == [.clean], "\(phase)")
            #expect(!bar.actions[0].isEnabled, "\(phase)")
        }

        #expect(content(.measuring(first: false), totalBytes: 5_000).suffix == .estimated)
    }

    @Test
    func cleaningCountsTheCategoriesAndShowsTheProgress() {
        let progress = CleanupProgress(
            totalCategories: 5,
            startedCategories: 3,
            currentCategory: .removeDerivedData,
            finishedItems: 3,
            freedBytes: 700
        )
        let hero = hero(.cleaning(progress))
        let bar = ActionBarContent(hero: hero, phase: .cleaning(progress), isShowingDetails: false)

        #expect(bar.eyebrow.key == "Cleaning · %lld of %lld")
        #expect(bar.suffix == .freed)
        #expect(bar.progress == hero.progress)
        #expect(bar.progress != nil)
        #expect(bar.actions.map(\.kind) == [.cancel])
        #expect(bar.actions[0].isEnabled)
        #expect(bar.shortcut(for: .cancel) == .cancel)
    }

    @Test
    func cancellingWaitsForTheCurrentItem() {
        let bar = content(.cancelling(freedBytes: 700))

        #expect(bar.actions.map(\.kind) == [.cancel])
        #expect(!bar.actions[0].isEnabled)
        #expect(bar.progress == nil)
        #expect(bar.suffix == .freed)
    }

    /// The secondary action sits on the left and the main one on the right, as in the layout.
    @Test
    func theMainActionComesLast() {
        let partial = CleanupReport(results: [result(.removed), result(.failed(.inUse), id: .removeCaches)])
        let failure = CleanupReport(results: [result(.failed(.inUse))])

        #expect(content(.finished(partial)).actions.map(\.kind) == [.toggleDetails, .retry])
        #expect(content(.finished(failure)).actions.map(\.kind) == [.toggleDetails, .retry])
        #expect(content(.permissionDenied(failure)).actions.map(\.kind) == [.retry, .openPrivacySettings])

        for phase: CleanerPhase in [.finished(partial), .finished(failure), .permissionDenied(failure)] {
            #expect(content(phase).actions.last?.style == .prominent, "\(phase)")
        }
    }

    @Test
    func theDetailsButtonFollowsTheOpenDetails() {
        let partial = CleanupReport(results: [result(.removed), result(.failed(.inUse), id: .removeCaches)])
        let hidden = content(.finished(partial))
        let shown = content(.finished(partial), isShowingDetails: true)

        #expect(hidden.actions.map(\.title.key) == ["See details", "Try again (%lld)"])
        #expect(shown.actions.map(\.title.key) == ["Hide details", "Try again (%lld)"])
        #expect(shown.symbol?.tint == .attention)
    }

    /// Only Cancel (Esc) and OK (Return) have shortcuts; nothing starts a cleanup from the keyboard.
    @Test
    func onlyCancelAndOKHaveShortcuts() {
        let bar = content(.finished(CleanupReport(results: [result(.removed)])))

        #expect(bar.actions.map(\.kind) == [.dismiss])
        #expect(bar.shortcut(for: .dismiss) == .default)
        #expect(bar.suffix == .freed)
        #expect(bar.symbol?.tint == .success)

        for kind: HeroContent.Action.Kind in [.clean, .retry, .toggleDetails, .openPrivacySettings, .supportProject] {
            #expect(bar.shortcut(for: kind) == nil, "\(kind)")
        }
    }

    /// With the donation suggestion (C31), "Close" sits on the left and keeps Return; "Support
    /// the project" is the main action on the right, with no shortcut.
    @Test
    func theDonationSuggestionKeepsCloseOnTheLeft() {
        let phase = CleanerPhase.finished(CleanupReport(results: [result(.removed)]))
        let hero = HeroContent(
            phase: phase,
            totalBytes: 0,
            foundBytes: 0,
            measuredCategoryCount: 3,
            categoryCount: 15,
            suggestsDonation: true
        )
        let bar = ActionBarContent(hero: hero, phase: phase, isShowingDetails: false)

        #expect(bar.actions.map(\.kind) == [.dismiss, .supportProject])
        #expect(bar.actions.map(\.style) == [.plain, .support])
        #expect(bar.shortcut(for: .dismiss) == .default)
        #expect(bar.shortcut(for: .supportProject) == nil)
        #expect(bar.symbol?.tint == .success)
        #expect(bar.suffix == .freed)
    }

    // MARK: - Private Methods

    private func content(
        _ phase: CleanerPhase,
        totalBytes: Int64 = 0,
        isShowingDetails: Bool = false
    ) -> ActionBarContent {
        ActionBarContent(hero: hero(phase, totalBytes: totalBytes), phase: phase, isShowingDetails: isShowingDetails)
    }

    private func hero(_ phase: CleanerPhase, totalBytes: Int64 = 0) -> HeroContent {
        HeroContent(
            phase: phase,
            totalBytes: totalBytes,
            foundBytes: totalBytes,
            measuredCategoryCount: 3,
            categoryCount: 15
        )
    }

    private func result(
        _ outcome: CleanupItemResult.Outcome,
        id: CleanupCategoryID = .removeDerivedData
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: 100, outcome: outcome)
    }

}
