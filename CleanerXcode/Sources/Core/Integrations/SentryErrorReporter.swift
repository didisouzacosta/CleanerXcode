//
//  SentryErrorReporter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Sentry

/// Sends crashes and aggregated cleanup failures to Sentry. Only `AppContainer` creates it,
/// never for tests or previews, and only when a DSN is configured.
final class SentryErrorReporter: ErrorReporting {

    // MARK: - Private Properties

    private let configuration: ErrorReportingConfiguration

    // MARK: - Initializers

    init(configuration: ErrorReportingConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public Static Methods

    static func makeOptions(for configuration: ErrorReportingConfiguration) -> Options {
        let options = Options()

        options.dsn = configuration.dsn
        options.environment = configuration.environment
        options.releaseName = configuration.releaseName
        options.dist = configuration.dist
        options.sampleRate = NSNumber(value: configuration.sampleRate)
        options.tracesSampleRate = NSNumber(value: configuration.tracesSampleRate)
        options.sendDefaultPii = false
        options.enableUncaughtNSExceptionReporting = true
        options.debug = false

        // Release-health sessions carry Sentry's installation ID and never pass through `beforeSend`.
        options.enableAutoSessionTracking = false

        // Static nonisolated functions, not closures formed here: Sentry calls them off the main thread.
        options.beforeSend = SentryEventSanitizer.sanitize
        options.beforeBreadcrumb = SentryEventSanitizer.sanitizeBreadcrumb

        return options
    }

    // MARK: - Private Static Methods

    private static func sentryLevel(for level: ReportableFailure.Level) -> SentryLevel {
        switch level {
        case .warning: .warning
        }
    }

    nonisolated private static func scopeConfiguration(
        level: SentryLevel,
        tags: [String: String],
        counts: [String: Int],
        extras: [String: String]
    ) -> (Scope) -> Void {
        { scope in
            scope.setLevel(level)
            scope.setTags(tags)

            for (key, count) in counts {
                scope.setExtra(value: count, key: key)
            }

            for (key, value) in extras {
                scope.setExtra(value: value, key: key)
            }
        }
    }

    // MARK: - Public Methods

    func start() {
        SentrySDK.start(options: Self.makeOptions(for: configuration))
    }

    func capture(_ failure: ReportableFailure) {
        let configureScope = Self.scopeConfiguration(
            level: Self.sentryLevel(for: failure.level),
            tags: failure.tags,
            counts: failure.counts,
            extras: failure.extras
        )

        SentrySDK.capture(message: failure.message, block: configureScope)
    }

    func breadcrumb(_ stage: ReportingStage) {
        let breadcrumb = Breadcrumb(level: .info, category: "cleanup")
        breadcrumb.message = stage.rawValue

        SentrySDK.addBreadcrumb(breadcrumb)
    }

}
