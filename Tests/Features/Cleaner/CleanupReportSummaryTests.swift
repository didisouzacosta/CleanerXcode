//
//  CleanupReportSummaryTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
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

    /// The row of a category tells its single failure, and the permission notice names the
    /// folder when macOS blocked only one.
    @Test
    func groupsTheFailuresByCategoryAndPermission() {
        let report = CleanupReport(results: [
            result(.removeDerivedData, .failed(.inUse)),
            result(.removeDerivedData, .failed(.permissionDenied)),
            result(.removeCaches, .removed),
            result(.removeArchives, .failed(.permissionDenied)),
        ])

        #expect(report.failedResults(of: .removeDerivedData).count == 2)
        #expect(report.failedResults(of: .removeCaches).isEmpty)
        #expect(report.permissionDeniedResults.map(\.categoryID) == [.removeDerivedData, .removeArchives])
    }

    /// The approved layout shows the system code next to the reason when it is known.
    @Test
    func theReasonCarriesTheKnownSystemCode() {
        #expect(CleanupError.inUse.summary.key == "In use by another process (EBUSY)")
        #expect(CleanupError.commandFailed(exitCode: 164, summary: "").summary.key == "The command failed (code %lld)")
        #expect(CleanupError.permissionDenied.summary.key == "No permission")
    }

    // MARK: - Private Methods

    private func result(_ id: CleanupCategoryID, _ outcome: CleanupItemResult.Outcome) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: 1, outcome: outcome)
    }

}
