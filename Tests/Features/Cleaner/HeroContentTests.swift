//
//  HeroContentTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

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
        let content = hero(.cancelling)

        #expect(content.actions.map(\.kind) == [.cancel])
        #expect(!content.actions[0].isEnabled)
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
        #expect(hero(.finished(failure)).symbol?.tint == .attention)
        #expect(hero(.finished(cancelled)).symbol?.tint != .success)
        #expect(hero(.permissionDenied(failure)).symbol?.tint == .failure)
    }

    // MARK: - Private Methods

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
