//
//  CleanupProgressTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Testing
@testable import CleanerXcode

/// How each executor event moves the cleanup's progress, the hero's numbers while cleaning.
struct CleanupProgressTests {

    // MARK: - Public Methods

    @Test
    func aStartedCategoryBecomesTheCurrentOne() {
        var progress = CleanupProgress(totalCategories: 2)

        progress.apply(.categoryStarted(.removeDerivedData))

        #expect(progress.startedCategories == 1)
        #expect(progress.currentCategory == .removeDerivedData)
    }

    @Test
    func aRemovedItemCountsAsFreed() {
        var progress = CleanupProgress(totalCategories: 1)

        progress.apply(.itemFinished(result(.removed, bytes: 300)))

        #expect(progress.finishedItems == 1)
        #expect(progress.freedBytes == 300)
        #expect(progress.trashedBytes == 0)
    }

    @Test
    func aTrashedItemCountsAsTrashed() {
        var progress = CleanupProgress(totalCategories: 1)

        progress.apply(.itemFinished(result(.trashed, bytes: 500)))

        #expect(progress.finishedItems == 1)
        #expect(progress.freedBytes == 0)
        #expect(progress.trashedBytes == 500)
    }

    @Test
    func aSkippedItemOnlyCountsAsFinished() {
        var progress = CleanupProgress(totalCategories: 1)

        progress.apply(.itemFinished(result(.skipped(.inUse), bytes: 700)))

        #expect(progress == CleanupProgress(totalCategories: 1, finishedItems: 1))
    }

    @Test(arguments: [CleanupEvent.closingSimulators, .restartingSimulatorService])
    func closingOrRestartingTheSimulatorsChangesNothing(event: CleanupEvent) {
        var progress = CleanupProgress(totalCategories: 1)

        progress.apply(event)

        #expect(progress == CleanupProgress(totalCategories: 1))
    }

    // MARK: - Private Methods

    private func result(_ outcome: CleanupItemResult.Outcome, bytes: Int64) -> CleanupItemResult {
        CleanupItemResult(categoryID: .removeDerivedData, displayPath: "~/x", bytes: bytes, outcome: outcome)
    }

}
