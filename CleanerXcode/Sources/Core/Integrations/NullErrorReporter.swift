//
//  NullErrorReporter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Used by tests, previews and builds without a Sentry DSN.
struct NullErrorReporter: ErrorReporting {

    // MARK: - Public Methods

    func start() {}

    func capture(_ failure: ReportableFailure) {}

    func breadcrumb(_ stage: ReportingStage) {}

}
