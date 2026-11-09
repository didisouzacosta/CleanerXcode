//
//  SimulatorSDKReading.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// The simulator SDK version of each platform in the selected Xcode: the version the default
/// download installs, and the newest one offered (C35, R3).
nonisolated protocol SimulatorSDKReading: Sendable {
    /// Missing tools throw `.toolUnavailable`; cancellation terminates the command.
    func simulatorSDKVersions() async throws -> [RuntimePlatform: RuntimeBuildVersion]
}

/// Reads `xcodebuild -showsdks -json` through `xcrun`, without a shell. Only each SDK's `platform`
/// and `sdkVersion` are read; paths and the other fields are ignored.
nonisolated struct XcodebuildSimulatorSDKReader: SimulatorSDKReading {

    // MARK: - Public Properties

    /// The JSON of `xcodebuild -showsdks` could not be read.
    static let unreadableOutput = CleanupError.unknown(domain: "XcodebuildShowSDKs", code: 1)

    // MARK: - Private Properties

    private let runner: any ProcessRunning

    // MARK: - Initializers

    init(runner: any ProcessRunning = ProcessRunner()) {
        self.runner = runner
    }

    // MARK: - Private Static Methods

    /// A platform listed twice keeps its newest version.
    @concurrent
    private static func versions(from data: Data) async throws -> [RuntimePlatform: RuntimeBuildVersion] {
        let sdks: [LossyElement<SDK>]

        do {
            sdks = try JSONDecoder().decode([LossyElement<SDK>].self, from: data)
        } catch {
            throw unreadableOutput
        }

        var versions: [RuntimePlatform: RuntimeBuildVersion] = [:]

        for sdk in sdks.compactMap(\.value) {
            guard
                let platform = sdk.platform.flatMap(RuntimePlatform.init(sdkPlatformName:)),
                let version = sdk.sdkVersion.flatMap(RuntimeBuildVersion.init)
            else { continue }

            if
                let current = versions[platform],
                RuntimeBuildVersion.compareNumerically(current, version) != .orderedAscending
            {
                continue
            }

            versions[platform] = version
        }

        return versions
    }

    // MARK: - Public Methods

    func simulatorSDKVersions() async throws -> [RuntimePlatform: RuntimeBuildVersion] {
        let output: ProcessOutput

        do {
            output = try await runner.run(.xcrun(["xcodebuild", "-showsdks", "-json"]))
        } catch {
            throw XcrunFailure.normalized(error)
        }

        return try await Self.versions(from: output.standardOutput)
    }

    // MARK: - Nested Types

    private struct SDK: Decodable {
        let platform: String?
        let sdkVersion: String?
    }

}
