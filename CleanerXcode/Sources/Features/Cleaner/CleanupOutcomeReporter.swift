//
//  CleanupOutcomeReporter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Turns a cleanup into the analytics events and the single aggregated error report (R21, R22).
/// Only enumerated values and counts leave the app: never paths.
struct CleanupOutcomeReporter {

    // MARK: - Private Properties

    private let analytics: any Analytics
    private let errorReporter: any ErrorReporting

    // MARK: - Initializers

    init(analytics: any Analytics, errorReporter: any ErrorReporting) {
        self.analytics = analytics
        self.errorReporter = errorReporter
    }

    // MARK: - Private Static Methods

    private static func resultKind(of outcome: CleanupReport.Outcome) -> AnalyticsEvent.CleanupResultKind {
        switch outcome {
        case .success: .success
        case .partialFailure: .partialFailure
        case .failure: .failure
        case .cancelled: .cancelled
        }
    }

    private static func errorKind(of error: CleanupError) -> AnalyticsEvent.CleanupErrorKind {
        switch error {
        case .permissionDenied: .permission
        case .inUse: .inUse
        case .toolUnavailable: .toolUnavailable
        case .timedOut: .timeout
        case .commandFailed: .commandFailed
        default: .other
        }
    }

    // MARK: - Public Methods

    func started() {
        errorReporter.breadcrumb(.cleanupStarted)
    }

    /// One `cleaner` event with the space really freed, and, when something failed, one
    /// `cleaner_partial_failure` event and one error report for the whole run.
    func finished(_ report: CleanupReport, for plan: CleanupPlan) {
        errorReporter.breadcrumb(.cleanupFinished)
        analytics.log(.cleaner(
            categories: plan.categories.map(\.id.rawValue),
            result: Self.resultKind(of: report.outcome),
            freedBytes: report.freedBytes
        ))

        guard !report.failedResults.isEmpty else { return }

        let failedCategories = report.failedCategoryIDs.map(\.rawValue)
        let errorKinds = report.failedResults.compactMap { result -> AnalyticsEvent.CleanupErrorKind? in
            guard case let .failed(error) = result.outcome else { return nil }

            return Self.errorKind(of: error)
        }

        analytics.log(.cleanerPartialFailure(failedCategories: failedCategories, errorKinds: errorKinds))
        errorReporter.capture(.cleanupFailed(
            failedCategories: failedCategories,
            errorKinds: errorKinds,
            totalCategories: plan.categories.count
        ))
    }

}
