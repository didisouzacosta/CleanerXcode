//
//  AppEnvironmentTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct AppEnvironmentTests {

    // MARK: - Public Methods

    @Test
    func detectsTestsFromXCTestConfigurationFilePath() {
        let environment = AppEnvironment(
            processEnvironment: ["XCTestConfigurationFilePath": "/tmp/config.xctestconfiguration"],
            isDebug: true
        )

        #expect(environment.isRunningTests)
    }

    @Test
    func detectsTestsFromXCTestBundlePath() {
        let environment = AppEnvironment(
            processEnvironment: ["XCTestBundlePath": "/tmp/CleanerXcodeTests.xctest"],
            isDebug: false
        )

        #expect(environment.isRunningTests)
    }

    @Test
    func isNotRunningTestsWithoutXCTestVariables() {
        let environment = AppEnvironment(
            processEnvironment: ["HOME": "/Users/someone"],
            isDebug: false
        )

        #expect(environment.isRunningTests == false)
        #expect(environment.isDebug == false)
    }

    @Test
    func detectsXcodePreviews() {
        let environment = AppEnvironment(
            processEnvironment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"],
            isDebug: true
        )

        #expect(environment.isRunningPreviews)
        #expect(environment.isRunningTests == false)
    }

    @Test
    func isNotRunningPreviewsWithoutThePreviewVariable() {
        let environment = AppEnvironment(
            processEnvironment: ["XCODE_RUNNING_FOR_PREVIEWS": "0"],
            isDebug: true
        )

        #expect(environment.isRunningPreviews == false)
    }

    @Test
    func detectsTheHostedTestProcess() {
        let environment = AppEnvironment.current()

        #expect(environment.isRunningTests)
    }

    @Test
    func hostedTestProcessGetsInertServices() {
        let services = AppContainer.makeServices(
            environment: .current(),
            configuration: AppConfiguration(versionFileURL: nil)
        )

        #expect(services.analytics is NullAnalytics)
        #expect(services.errorReporter is NullErrorReporter)
        #expect(services.userDefaults !== UserDefaults.standard)
    }

}
