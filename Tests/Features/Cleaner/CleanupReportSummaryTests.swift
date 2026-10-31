//
//  CleanupReportSummaryTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

struct CleanupReportSummaryTests {

    // MARK: - Public Methods

    /// "3 of 5 categories" in the hero: a category with any failure is not counted as cleaned,
    /// and a category whose items were all skipped still finished.
    @Test
    func countsTheCategoriesThatFinishedWithoutAFailure() {
        let report = CleanupReport(results: [
            result(.removeDerivedData, .removed),
            result(.removeDerivedData, .failed(.inUse)),
            result(.removeCaches, .removed),
            result(.removeArchives, .trashed),
            result(.removeSwiftPMCache, .skipped(.notFound)),
        ])

        #expect(report.finishedCategoryCount == 3)
        #expect(report.failedCategoryIDs.count == 1)
    }

    @Test
    func anEmptyRunFinishedNothing() {
        #expect(CleanupReport(results: []).finishedCategoryCount == 0)
    }

    // MARK: - Private Methods

    private func result(_ id: CleanupCategoryID, _ outcome: CleanupItemResult.Outcome) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: 1, outcome: outcome)
    }

}
