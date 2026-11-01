//
//  OverviewPresentationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The caption next to "Sections" and the style of the cards (Figma page 08): counts only while
/// nothing runs.
struct OverviewPresentationTests {

    // MARK: - Public Methods

    @Test
    func countsTheSelectedCategoriesWhileIdle() {
        for phase: CleanerPhase in [
            .ready,
            .confirming(CleanupPlan(categories: [])),
            .nothingSelected,
            .nothingToClean,
        ] {
            let caption = OverviewPresentation.sectionsCaption(phase: phase, selectedCount: 4)

            #expect(caption?.key == "%lld categories with selected items", "\(phase)")
            #expect(OverviewPresentation.cardStyle(phase: phase) == .count, "\(phase)")
        }
    }

    @Test
    func hidesTheCaptionWhileMeasuringCleaningOrShowingAReport() {
        let report = CleanupReport(results: [])

        for phase: CleanerPhase in [
            .measuring(first: true),
            .measuring(first: false),
            .cleaning(CleanupProgress(totalCategories: 2)),
            .cancelling(freedBytes: 0),
            .finished(report),
            .permissionDenied(report),
        ] {
            #expect(OverviewPresentation.sectionsCaption(phase: phase, selectedCount: 4) == nil, "\(phase)")
            #expect(OverviewPresentation.cardStyle(phase: phase) == .bytes, "\(phase)")
        }
    }

    /// The failed items close when their report is dismissed or replaced; a first report keeps
    /// them as they were, so a preview can start with them open (review V2).
    @Test
    func theFailedItemsCloseOnlyWhenAReportLeaves() {
        let report = CleanupReport(results: [])

        #expect(!OverviewPresentation.closesFailures(whenReportChangesFrom: nil))
        #expect(OverviewPresentation.closesFailures(whenReportChangesFrom: report))
    }

}
