//
//  HeroContentTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The actions and figures of the hero in each phase; the texts themselves live in the catalog.
struct HeroContentTests {

    // MARK: - Public Methods

    @Test
    func readyOffersTheEstimatedTotal() {
        let content = hero(.ready, totalBytes: 5_000)

        #expect(content.actions.map(\.kind) == [.clean])
        #expect(content.actions.allSatisfy { $0.isEnabled })
        #expect(!content.isFreedAmount)
        #expect(content.progress == nil)
    }

    @Test
    func theButtonIsDisabledWhileMeasuringOrWithNothingToDo() {
        for phase: CleanerPhase in [
            .measuring(first: true),
            .measuring(first: false),
            .nothingSelected,
            .nothingToClean,
        ] {
            let content = hero(phase)

            #expect(content.actions.map(\.kind) == [.clean], "\(phase)")
            #expect(!content.actions.contains { $0.isEnabled }, "\(phase)")
        }
    }

    @Test
    func theButtonWaitsDuringAConfirmation() {
        let content = hero(.confirming(CleanupPlan(categories: [])), totalBytes: 5_000)

        #expect(content.actions.map(\.kind) == [.clean])
        #expect(!content.actions.contains { $0.isEnabled })
    }

    @Test
    func cleaningShowsTheProgressAndCanBeCancelled() {
        let progress = CleanupProgress(
            totalCategories: 4,
            startedCategories: 2,
            currentCategory: .removeDerivedData,
            finishedItems: 3,
            freedBytes: 700
        )
        let content = hero(.cleaning(progress))

        #expect(content.actions.map(\.kind) == [.cancel])
        #expect(content.actions[0].style == .destructive)
        #expect(content.actions[0].isEnabled)
        #expect(content.isFreedAmount)
        #expect(content.progress == 0.25, "Only the first category has finished.")
    }

    @Test
    func cancellingWaitsForTheCurrentItem() {
        let content = hero(.cancelling(freedBytes: 700))

        #expect(content.actions.map(\.kind) == [.cancel])
        #expect(!content.actions[0].isEnabled)
        #expect(content.isFreedAmount, "What was freed before cancelling stays on screen.")
        #expect(content.amount == hero(.finished(CleanupReport(results: [result(.removed, bytes: 700)]))).amount)
    }

    /// "Freed" only follows an amount that was actually freed, never "0 KB freed".
    @Test
    func nothingFreedShowsNoFreedLabel() {
        let failure = CleanupReport(results: [result(.failed(.permissionDenied))])

        #expect(!hero(.finished(failure)).isFreedAmount)
        #expect(!hero(.permissionDenied(failure)).isFreedAmount)
        #expect(!hero(.cancelling(freedBytes: 0)).isFreedAmount)
        #expect(hero(.finished(failure)).isAmountDimmed, "\"0 KB\" in grey, as in the approved layout.")
        #expect(hero(.permissionDenied(failure)).isAmountDimmed)
        #expect(!hero(.ready, totalBytes: 0).isAmountDimmed, "Only a run that freed nothing is dimmed.")
        #expect(!hero(.finished(CleanupReport(results: [result(.removed)]))).isAmountDimmed)
    }

    /// The retry counts the failed items, as in the approved layout; a run where nothing was
    /// removed just offers to try again.
    @Test
    func theRetryCountsTheFailedItems() {
        let partial = CleanupReport(results: [
            result(.removed, id: .removeCaches),
            result(.failed(.inUse)),
            result(.failed(.permissionDenied)),
        ])
        let failure = CleanupReport(results: [result(.failed(.inUse))])

        #expect(hero(.finished(partial)).actions.map(\.title.key) == ["Try again (%lld)", "See details"])
        #expect(hero(.finished(failure)).actions.map(\.title.key) == ["Try again", "See details"])
    }

    @Test
    func eachReportHasItsOwnActions() {
        let success = CleanupReport(results: [result(.removed)])
        let partial = CleanupReport(results: [result(.removed), result(.failed(.inUse), id: .removeCaches)])
        let failure = CleanupReport(results: [result(.failed(.inUse))])
        let cancelled = CleanupReport(results: [result(.removed)], wasCancelled: true)

        #expect(hero(.finished(success)).actions.map(\.kind) == [.dismiss])
        #expect(hero(.finished(partial)).actions.map(\.kind) == [.retry, .toggleDetails])
        #expect(hero(.finished(failure)).actions.map(\.kind) == [.retry, .toggleDetails])
        #expect(hero(.finished(cancelled)).actions.map(\.kind) == [.dismiss])
        #expect(hero(.permissionDenied(failure)).actions.map(\.kind) == [.openPrivacySettings, .retry])
        #expect(hero(.finished(success)).isFreedAmount)
    }

    /// Never a success when anything failed or the run was cancelled (R6).
    @Test
    func onlyASuccessfulRunShowsTheSuccessSymbol() {
        let partial = CleanupReport(results: [result(.removed), result(.failed(.inUse), id: .removeCaches)])
        let failure = CleanupReport(results: [result(.failed(.inUse))])
        let cancelled = CleanupReport(results: [result(.removed)], wasCancelled: true)

        #expect(hero(.finished(CleanupReport(results: [result(.removed)]))).symbol?.tint == .success)
        #expect(hero(.finished(partial)).symbol?.tint == .attention)
        #expect(hero(.finished(failure)).symbol?.tint == .failure, "Nothing removed: the red cross (Figma 17:10078).")
        #expect(hero(.finished(cancelled)).symbol?.tint != .success)
        #expect(hero(.permissionDenied(failure)).symbol?.tint == .failure)
    }

    /// The summary card's indicator: a progress bar while the first measurement or a cleanup
    /// runs, the space bar while idle, and nothing on a report (Figma page 08).
    @Test
    func eachPhaseHasItsIndicator() {
        let progress = CleanupProgress(totalCategories: 4, startedCategories: 2, currentCategory: .removeCaches)
        let report = CleanupReport(results: [result(.removed)])

        #expect(hero(.measuring(first: true)).indicator == .progress(0.2), "3 of 15 categories measured.")
        #expect(hero(.cleaning(progress)).indicator == .progress(0.25))

        for phase: CleanerPhase in [
            .measuring(first: false),
            .ready,
            .confirming(CleanupPlan(categories: [])),
            .nothingSelected,
            .nothingToClean,
        ] {
            #expect(hero(phase).indicator == .breakdown, "\(phase)")
        }

        for phase: CleanerPhase in [.cancelling(freedBytes: 1), .finished(report), .permissionDenied(report)] {
            #expect(hero(phase).indicator == HeroContent.Indicator.none, "\(phase)")
        }
    }

    /// The fifth, tenth… success suggests a donation instead of OK (C31): the main action supports
    /// the project and "Close" stays as a text button.
    @Test
    func aSuccessCanSuggestADonation() {
        let content = hero(.finished(CleanupReport(results: [result(.removed)])), suggestsDonation: true)

        #expect(content.actions.map(\.kind) == [.supportProject, .dismiss])
        #expect(content.actions.map(\.style) == [.support, .plain])
        #expect(content.actions.map(\.title.key) == ["Support the project", "Close"])
        #expect(content.actions.allSatisfy { $0.isEnabled })
        #expect(
            content.detail == String(localized: "Enjoying it? Any amount helps — 100% goes to shelters and hospitals")
        )
        #expect(content.symbol?.tint == .success)
        #expect(content.isFreedAmount)
    }

    @Test
    func withoutTheSuggestionASuccessKeepsOK() {
        let content = hero(.finished(CleanupReport(results: [result(.removed)])))

        #expect(content.actions.map(\.kind) == [.dismiss])
        #expect(content.actions.map(\.style) == [.secondary])
        #expect(content.actions.map(\.title.key) == ["OK"])
        #expect(content.detail == String(localized: "\(1) categories cleaned"))
    }

    /// Never on any other outcome or phase, even if the flag were left on (R6).
    @Test
    func onlyASuccessShowsTheSuggestion() {
        let partial = CleanupReport(results: [result(.removed), result(.failed(.inUse), id: .removeCaches)])
        let failure = CleanupReport(results: [result(.failed(.inUse))])
        let cancelled = CleanupReport(results: [result(.removed)], wasCancelled: true)

        for phase: CleanerPhase in [
            .ready,
            .measuring(first: false),
            .cancelling(freedBytes: 1),
            .finished(partial),
            .finished(failure),
            .finished(cancelled),
            .permissionDenied(failure),
        ] {
            let plain = hero(phase)
            let flagged = hero(phase, suggestsDonation: true)

            #expect(flagged.actions.map(\.kind) == plain.actions.map(\.kind), "\(phase)")
            #expect(flagged.actions.map(\.style) == plain.actions.map(\.style), "\(phase)")
            #expect(flagged.detail == plain.detail, "\(phase)")
        }
    }

    /// The window no longer lists the categories below the total (Figma page 08).
    @Test
    func nothingSelectedNoLongerPointsBelow() {
        #expect(hero(.nothingSelected).detail == String(localized: "Select at least one category"))
    }

    // MARK: - Private Methods

    private func hero(_ phase: CleanerPhase, totalBytes: Int64 = 0, suggestsDonation: Bool = false) -> HeroContent {
        HeroContent(
            phase: phase,
            totalBytes: totalBytes,
            foundBytes: totalBytes,
            measuredCategoryCount: 3,
            categoryCount: 15,
            suggestsDonation: suggestsDonation
        )
    }

    private func result(
        _ outcome: CleanupItemResult.Outcome,
        id: CleanupCategoryID = .removeDerivedData,
        bytes: Int64 = 100
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: bytes, outcome: outcome)
    }

}
