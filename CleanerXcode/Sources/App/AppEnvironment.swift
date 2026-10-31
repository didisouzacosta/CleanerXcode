//
//  AppEnvironment.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated struct AppEnvironment: Equatable, Sendable {

    // MARK: - Public Properties

    let isRunningTests: Bool
    let isRunningPreviews: Bool
    let isDebug: Bool

    // MARK: - Initializers

    init(isRunningTests: Bool, isRunningPreviews: Bool = false, isDebug: Bool) {
        self.isRunningTests = isRunningTests
        self.isRunningPreviews = isRunningPreviews
        self.isDebug = isDebug
    }

    init(processEnvironment: [String: String], isDebug: Bool) {
        let testVariables = ["XCTestConfigurationFilePath", "XCTestBundlePath"]
        let isRunningTests = testVariables.contains { processEnvironment[$0] != nil }
        let isRunningPreviews = processEnvironment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        self.init(isRunningTests: isRunningTests, isRunningPreviews: isRunningPreviews, isDebug: isDebug)
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

}
