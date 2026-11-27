//
//  ErrorReportingConfigurationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

struct ErrorReportingConfigurationTests {

    // MARK: - Private Properties

    private let dsn = "https://key@o1.ingest.sentry.io/2"

    // MARK: - Public Methods

    @Test
    func debugBuildReportsToTheDebugEnvironment() {
        let configuration = ErrorReportingConfiguration(
            dsn: dsn,
            bundleIdentifier: "didisouzacosta.CleanerXcode",
            version: "1.0.0",
            build: "120",
            isDebug: true
        )

        #expect(configuration.dsn == dsn)
        #expect(configuration.environment == "debug")
        #expect(configuration.releaseName == "didisouzacosta.CleanerXcode@1.0.0+120")
        #expect(configuration.dist == "120")
        #expect(configuration.sampleRate == 1.0)
        #expect(configuration.tracesSampleRate == 0.0)
    }

    @Test
    func releaseBuildReportsToTheProductionEnvironment() {
        let configuration = ErrorReportingConfiguration(
            dsn: dsn,
            bundleIdentifier: "didisouzacosta.CleanerXcode",
            version: "1.0.1",
            build: "121",
            isDebug: false
        )

        #expect(configuration.environment == "production")
        #expect(configuration.releaseName == "didisouzacosta.CleanerXcode@1.0.1+121")
        #expect(configuration.sampleRate == 1.0)
        #expect(configuration.tracesSampleRate == 0.0)
    }

    @Test
    func missingBundleValuesStillProduceAValidRelease() {
        let configuration = ErrorReportingConfiguration(
            dsn: dsn,
            bundleIdentifier: nil,
            version: nil,
            build: nil,
            isDebug: false
        )

        #expect(configuration.releaseName == "com.didisouzacosta.CleanerXcode@unknown+unknown")
        #expect(configuration.dist == "unknown")
    }

}
