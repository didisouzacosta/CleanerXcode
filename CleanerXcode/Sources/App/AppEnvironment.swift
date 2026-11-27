//
//  AppEnvironment.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated struct AppEnvironment: Equatable, Sendable {

    // MARK: - Public Properties

    /// `CLEANERXCODE_DEMO=1` turns on the demo (C36): mocked data and a scripted tour of the window.
    static let demoVariable = "CLEANERXCODE_DEMO"
    /// Seconds before the tour starts, so a screen recording can begin first.
    static let demoStartDelayVariable = "CLEANERXCODE_DEMO_START_DELAY"
    static let defaultDemoStartDelay: Duration = .seconds(3)
    static let maximumDemoStartDelaySeconds = 120.0

    let isRunningTests: Bool
    let isRunningPreviews: Bool
    let isDebug: Bool
    /// Only in Debug builds, and never in tests or previews: Release ignores the variable.
    let isDemo: Bool
    let demoStartDelay: Duration

    /// Tests, previews and the demo never touch the system nor start a third-party SDK.
    var isInert: Bool {
        isRunningTests || isRunningPreviews || isDemo
    }

    // MARK: - Initializers

    init(
        isRunningTests: Bool,
        isRunningPreviews: Bool = false,
        isDebug: Bool,
        isDemo: Bool = false,
        demoStartDelay: Duration = defaultDemoStartDelay
    ) {
        self.isRunningTests = isRunningTests
        self.isRunningPreviews = isRunningPreviews
        self.isDebug = isDebug
        self.isDemo = isDemo && isDebug && !isRunningTests && !isRunningPreviews
        self.demoStartDelay = demoStartDelay
    }

    init(processEnvironment: [String: String], isDebug: Bool) {
        let testVariables = ["XCTestConfigurationFilePath", "XCTestBundlePath"]
        let isRunningTests = testVariables.contains { processEnvironment[$0] != nil }
        let isRunningPreviews = processEnvironment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isDemo = processEnvironment[Self.demoVariable] == "1"
        let demoStartDelay = Self.demoStartDelay(from: processEnvironment[Self.demoStartDelayVariable])

        self.init(
            isRunningTests: isRunningTests,
            isRunningPreviews: isRunningPreviews,
            isDebug: isDebug,
            isDemo: isDemo,
            demoStartDelay: demoStartDelay
        )
    }

    // MARK: - Public Methods

    static func current(processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
        #if DEBUG
            let isDebug = true
        #else
            let isDebug = false
        #endif

        return AppEnvironment(processEnvironment: processInfo.environment, isDebug: isDebug)
    }

    // MARK: - Private Methods

    /// A finite number of seconds from 0 to the maximum; anything else keeps the default.
    private static func demoStartDelay(from value: String?) -> Duration {
        guard let value, let seconds = Double(value), seconds.isFinite else { return defaultDemoStartDelay }

        guard (0...maximumDemoStartDelaySeconds).contains(seconds) else { return defaultDemoStartDelay }

        return .milliseconds(Int((seconds * 1_000).rounded()))
    }

}
