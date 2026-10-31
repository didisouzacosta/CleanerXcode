//
//  SentryErrorReporterTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Sentry
import Testing
@testable import CleanerXcode

/// Only builds `Options`; the real SDK is never started from the tests.
struct SentryErrorReporterTests {

    // MARK: - Private Properties

    private let configuration = ErrorReportingConfiguration(
        dsn: "https://key@o1.ingest.sentry.io/2",
        bundleIdentifier: "didisouzacosta.CleanerXcode",
        version: "1.0.0",
        build: "120",
        isDebug: false
    )

    // MARK: - Public Methods

    @Test
    func optionsCarryTheConfiguration() {
        let options = SentryErrorReporter.makeOptions(for: configuration)

        #expect(options.dsn == "https://key@o1.ingest.sentry.io/2")
        #expect(options.environment == "production")
        #expect(options.releaseName == "didisouzacosta.CleanerXcode@1.0.0+120")
        #expect(options.dist == "120")
        #expect(options.sampleRate == 1.0)
        #expect(options.tracesSampleRate == 0.0)
    }

    @Test
    func optionsNeverSendPersonalData() {
        let options = SentryErrorReporter.makeOptions(for: configuration)

        #expect(options.sendDefaultPii == false)
        #expect(options.debug == false)
        #expect(options.enableUncaughtNSExceptionReporting)
    }

    /// Release-health sessions carry Sentry's installation ID and skip `beforeSend`.
    @Test
    func optionsDoNotTrackSessions() {
        let options = SentryErrorReporter.makeOptions(for: configuration)

        #expect(options.enableAutoSessionTracking == false)
    }

    @Test
    func optionsRouteEventsAndBreadcrumbsThroughTheSanitizer() throws {
        let options = SentryErrorReporter.makeOptions(for: configuration)
        let event = Event(level: .error)
        event.serverName = "Adrianos-MacBook-Pro"
        let breadcrumb = Breadcrumb(level: .info, category: "cleanup")
        breadcrumb.message = "/Users/adriano/Library"

        let beforeSend = try #require(options.beforeSend)
        let beforeBreadcrumb = try #require(options.beforeBreadcrumb)

        #expect(beforeSend(event)?.serverName == nil)
        #expect(beforeBreadcrumb(breadcrumb)?.message == "~/Library")
    }

}
