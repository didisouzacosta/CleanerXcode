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
    func debugBuildTurnsOnTheDemoWithItsVariable() {
        let environment = AppEnvironment(processEnvironment: ["CLEANERXCODE_DEMO": "1"], isDebug: true)

        #expect(environment.isDemo)
        #expect(environment.demoStartDelay == .seconds(3))
    }

    @Test
    func releaseBuildIgnoresTheDemoVariable() {
        let environment = AppEnvironment(processEnvironment: ["CLEANERXCODE_DEMO": "1"], isDebug: false)

        #expect(environment.isDemo == false)
    }

    @Test(arguments: [nil, "0", "yes", ""])
    func demoStaysOffWithoutTheExactVariable(value: String?) {
        let processEnvironment = value.map { ["CLEANERXCODE_DEMO": $0] } ?? [:]

        let environment = AppEnvironment(processEnvironment: processEnvironment, isDebug: true)

        #expect(environment.isDemo == false)
    }

    @Test
    func testsAndPreviewsNeverRunTheDemo() {
        let tests = AppEnvironment(
            processEnvironment: ["CLEANERXCODE_DEMO": "1", "XCTestBundlePath": "/tmp/Tests.xctest"],
            isDebug: true
        )
        let previews = AppEnvironment(
            processEnvironment: ["CLEANERXCODE_DEMO": "1", "XCODE_RUNNING_FOR_PREVIEWS": "1"],
            isDebug: true
        )

        #expect(tests.isDemo == false)
        #expect(previews.isDemo == false)
    }

    @Test
    func demoReadsItsStartDelay() {
        let environment = AppEnvironment(
            processEnvironment: ["CLEANERXCODE_DEMO": "1", "CLEANERXCODE_DEMO_START_DELAY": "1.5"],
            isDebug: true
        )

        #expect(environment.demoStartDelay == .milliseconds(1_500))
    }

    @Test(arguments: ["-2", "abc", "nan", "inf", "600"])
    func invalidStartDelayFallsBackToTheDefault(value: String) {
        let environment = AppEnvironment(
            processEnvironment: ["CLEANERXCODE_DEMO": "1", "CLEANERXCODE_DEMO_START_DELAY": value],
            isDebug: true
        )

        #expect(environment.demoStartDelay == .seconds(3))
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
