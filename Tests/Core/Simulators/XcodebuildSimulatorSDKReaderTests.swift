//
//  XcodebuildSimulatorSDKReaderTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The simulator SDK versions of the selected Xcode, from `xcodebuild -showsdks -json` (C35, R3,
/// AC14), with a fake runner and inline JSON: no test runs `xcodebuild`.
struct XcodebuildSimulatorSDKReaderTests {

    // MARK: - Private Properties

    private let showSDKs = ["xcodebuild", "-showsdks", "-json"]

    /// Only the fields the reader needs, plus others it must ignore; no real path.
    private let output = """
    [
      {"canonicalName": "iphoneos27.2", "platform": "iphoneos", "sdkVersion": "27.2"},
      {"canonicalName": "iphonesimulator27.2", "platform": "iphonesimulator", "sdkVersion": "27.2",
       "sdkPath": "/Applications/Example.app/SDKs/iPhoneSimulator.sdk"},
      {"platform": "watchsimulator", "sdkVersion": "27.2"},
      {"platform": "appletvsimulator", "sdkVersion": "27.1"},
      {"platform": "appletvsimulator", "sdkVersion": "27.2"},
      {"platform": "xrsimulator", "sdkVersion": "27.2"},
      {"platform": "macosx", "sdkVersion": "27.2"},
      {"platform": "driverkit", "sdkVersion": "27.2"}
    ]
    """

    // MARK: - Public Methods

    @Test
    func readsEachSimulatorSDKVersion() async throws {
        let runner = ProcessRunnerSpy(responses: [showSDKs: .success(output)])

        let versions = try await XcodebuildSimulatorSDKReader(runner: runner).simulatorSDKVersions()

        #expect(versions.mapValues(\.rawValue) == [
            .iOS: "27.2",
            .watchOS: "27.2",
            .tvOS: "27.2",
            .visionOS: "27.2",
        ])
        #expect(runner.requests == [.xcrun(showSDKs)])
        #expect(runner.requests.first?.timeout == ProcessRequest.defaultTimeout)
    }

    /// An entry without a platform or with a version that is not a plain number is left out.
    @Test
    func leavesOutEntriesItCannotRead() async throws {
        let runner = ProcessRunnerSpy(responses: [showSDKs: .success("""
        [
          {"platform": "iphonesimulator", "sdkVersion": "27.2 beta"},
          {"platform": "watchsimulator"},
          {"sdkVersion": "27.2"},
          {"platform": 7, "sdkVersion": "27.2"},
          "unexpected",
          {"platform": "xrsimulator", "sdkVersion": "27.2"}
        ]
        """)])

        let versions = try await XcodebuildSimulatorSDKReader(runner: runner).simulatorSDKVersions()

        #expect(versions.mapValues(\.rawValue) == [.visionOS: "27.2"])
    }

    @Test
    func exitCode72MeansTheToolsAreUnavailable() async {
        let runner = ProcessRunnerSpy(responses: [showSDKs: .failure(.commandFailed(exitCode: 72, summary: ""))])

        await #expect(throws: CleanupError.toolUnavailable) {
            try await XcodebuildSimulatorSDKReader(runner: runner).simulatorSDKVersions()
        }
    }

    @Test(arguments: ["not json", "{}", ""])
    func unreadableOutputFails(text: String) async {
        let runner = ProcessRunnerSpy(responses: [showSDKs: .success(text)])

        await #expect(throws: (any Error).self) {
            try await XcodebuildSimulatorSDKReader(runner: runner).simulatorSDKVersions()
        }
    }

}
