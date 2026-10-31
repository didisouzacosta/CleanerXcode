//
//  CleanupReportTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

struct CleanupReportTests {

    // MARK: - Public Methods

    @Test
    func everythingRemovedIsASuccessAndSumsTheFreedBytes() {
        let report = CleanupReport(results: [
            result(.removeDerivedData, bytes: 100, .removed),
            result(.removeCaches, bytes: 50, .removed),
        ])

        #expect(report.outcome == .success)
        #expect(report.freedBytes == 150)
        #expect(report.trashedBytes == 0)
        #expect(report.failedCategoryIDs.isEmpty)
    }

    @Test
    func trashedBytesAreCountedApartFromFreedBytes() {
        let report = CleanupReport(results: [
            result(.removeArchives, bytes: 700, .trashed),
            result(.removeDerivedData, bytes: 100, .removed),
        ])

        #expect(report.outcome == .success)
        #expect(report.freedBytes == 100)
        #expect(report.trashedBytes == 700)
    }

    @Test
    func skippedItemsNeverCountAsFailures() {
        let report = CleanupReport(results: [
            result(.clearTemporaryFiles, bytes: 10, .skipped(.inUse)),
            result(.removeDerivedData, bytes: 0, .skipped(.notFound)),
        ])

        #expect(report.outcome == .success)
        #expect(report.freedBytes == 0)
    }

    /// A missing item or an unsupported root is skipped, never a failure (R6).
    @Test
    func notFoundAndUnsupportedRootFailuresBecomeSkips() {
        let missing = result(.removeDerivedData, bytes: 0, .failed(.notFound))
        let symlinkedRoot = result(.removeArchives, bytes: 0, .failed(.unsupportedRoot))
        let report = CleanupReport(results: [missing, symlinkedRoot, result(.removeCaches, bytes: 9, .removed)])

        #expect(missing.outcome == .skipped(.notFound))
        #expect(symlinkedRoot.outcome == .skipped(.unsupportedRoot))
        #expect(report.outcome == .success)
        #expect(report.failedCategoryIDs.isEmpty)
    }

    @Test
    func someFailuresMakeAPartialFailureListingTheCategoriesInOrder() {
        let report = CleanupReport(results: [
            result(.removeDerivedData, bytes: 100, .removed),
            result(.removeCaches, bytes: 5, .failed(.permissionDenied)),
            result(.clearDeviceSupport, bytes: 5, .failed(.inUse)),
            result(.removeCaches, bytes: 5, .failed(.inUse)),
        ])

        #expect(report.outcome == .partialFailure)
        #expect(report.freedBytes == 100)
        #expect(report.failedCategoryIDs == [.removeCaches, .clearDeviceSupport])
        #expect(report.failedResults.count == 3)
    }

    @Test
    func onlyFailuresMakeAFailure() {
        let report = CleanupReport(results: [
            result(.removeCaches, bytes: 5, .failed(.permissionDenied)),
            result(.removeDerivedData, bytes: 0, .skipped(.notFound)),
        ])

        #expect(report.outcome == .failure)
    }

    @Test
    func cancellationWinsOverEverythingElseAndKeepsWhatWasFreed() {
        let report = CleanupReport(
            results: [
                result(.removeDerivedData, bytes: 100, .removed),
                result(.removeCaches, bytes: 5, .failed(.permissionDenied)),
            ],
            wasCancelled: true
        )

        #expect(report.outcome == .cancelled)
        #expect(report.freedBytes == 100)
    }

    @Test
    func emptyReportIsASuccess() {
        #expect(CleanupReport(results: []).outcome == .success)
    }

    // MARK: - Private Methods

    private func result(
        _ categoryID: CleanupCategoryID,
        bytes: Int64,
        _ outcome: CleanupItemResult.Outcome
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: categoryID, displayPath: "~/item", bytes: bytes, outcome: outcome)
    }

}
