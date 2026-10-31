//
//  ErrorReporting.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

protocol ErrorReporting {
    func start()
    func capture(_ failure: ReportableFailure)
    func breadcrumb(_ stage: ReportingStage)
}

/// Failures worth a report. Like `AnalyticsEvent`, they only carry enumerated values and counts:
/// never paths, file names, simulator names, UDIDs or exact sizes.
enum ReportableFailure: Equatable {

    // MARK: - Cases

    /// One aggregated event per cleanup, whatever the number of failed categories.
    case cleanupFailed(failedCategories: [String], errorKinds: [AnalyticsEvent.CleanupErrorKind], totalCategories: Int)

    // MARK: - Public Properties

    var message: String {
        switch self {
        case .cleanupFailed: "cleanup_partial_failure"
        }
    }

    var level: Level {
        switch self {
        case .cleanupFailed: .warning
        }
    }

    var tags: [String: String] {
        switch self {
        case let .cleanupFailed(failedCategories, errorKinds, totalCategories):
            let result: AnalyticsEvent.CleanupResultKind = failedCategories.count >= totalCategories
                ? .failure
                : .partialFailure

            return [
                "result": result.rawValue,
                "error_kinds": Set(errorKinds.map(\.rawValue)).sorted().joined(separator: ", "),
            ]
        }
    }

    /// Sentry tags are limited to 200 characters, which 15 category IDs exceed.
    var extras: [String: String] {
        switch self {
        case let .cleanupFailed(failedCategories, _, _):
            ["failed_categories": failedCategories.joined(separator: ", ")]
        }
    }

    var counts: [String: Int] {
        switch self {
        case let .cleanupFailed(failedCategories, _, totalCategories):
            ["failed_count": failedCategories.count, "total_count": totalCategories]
        }
    }

    // MARK: - Nested Types

    enum Level {
        case warning
    }

}

enum ReportingStage: String {
    case cleanupStarted = "cleanup_started"
    case cleanupFinished = "cleanup_finished"
}
