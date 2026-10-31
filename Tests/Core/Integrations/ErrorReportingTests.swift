//
//  ErrorReportingTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

struct ErrorReportingTests {

    // MARK: - Public Methods

    @Test
    func partialCleanupFailureBecomesASingleAggregatedWarning() {
        let failure = ReportableFailure.cleanupFailed(
            failedCategories: ["remove-caches"],
            errorKinds: [.other, .permission, .other],
            totalCategories: 3
        )

        #expect(failure.message == "cleanup_partial_failure")
        #expect(failure.level == .warning)
        #expect(failure.tags == [
            "result": "partial_failure",
            "error_kinds": "other, permission",
        ])
        #expect(failure.extras == ["failed_categories": "remove-caches"])
        #expect(failure.counts == ["failed_count": 1, "total_count": 3])
    }

    @Test
    func totalCleanupFailureKeepsTheAggregatedEventWithAFailureResult() {
        let failure = ReportableFailure.cleanupFailed(
            failedCategories: ["remove-archives", "remove-caches"],
            errorKinds: [.other],
            totalCategories: 2
        )

        #expect(failure.message == "cleanup_partial_failure")
        #expect(failure.tags["result"] == "failure")
        #expect(failure.extras["failed_categories"] == "remove-archives, remove-caches")
        #expect(failure.tags["failed_categories"] == nil, "Tags are limited to 200 characters; 15 IDs do not fit.")
        #expect(failure.counts == ["failed_count": 2, "total_count": 2])
    }

    @Test
    func reportingStagesUseStableNames() {
        #expect(ReportingStage.cleanupStarted.rawValue == "cleanup_started")
        #expect(ReportingStage.cleanupFinished.rawValue == "cleanup_finished")
    }

    @Test
    func nullReporterAcceptsEverythingSilently() {
        let reporter = NullErrorReporter()

        reporter.start()
        reporter.breadcrumb(.cleanupStarted)
        reporter.capture(.cleanupFailed(failedCategories: ["remove-caches"], errorKinds: [.other], totalCategories: 1))
    }

}
