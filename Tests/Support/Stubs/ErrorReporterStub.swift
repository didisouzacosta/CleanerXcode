//
//  ErrorReporterStub.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

@testable import CleanerXcode

final class ErrorReporterStub: ErrorReporting {

    // MARK: - Public Properties

    private(set) var startCount = 0
    private(set) var failures: [ReportableFailure] = []
    private(set) var stages: [ReportingStage] = []

    // MARK: - Public Methods

    func start() {
        startCount += 1
    }

    func capture(_ failure: ReportableFailure) {
        failures.append(failure)
    }

    func breadcrumb(_ stage: ReportingStage) {
        stages.append(stage)
    }

}
