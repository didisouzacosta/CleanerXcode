//
//  XcodebuildRuntimeDownloaderTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Synchronization
import Testing
@testable import CleanerXcode

/// `xcodebuild -downloadPlatform` through `xcrun`, checked with fake runners: no test ever runs
/// `xcodebuild` or downloads anything (C30, AC28).
struct XcodebuildRuntimeDownloaderTests {

    // MARK: - Private Properties

    private let downloadIOS = ["xcodebuild", "-downloadPlatform", "iOS"]

    // MARK: - Public Methods

    @Test
    func sendsTheDownloadPlatformCommandThroughXcrunWithTheLongTimeout() async throws {
        let runner = ProcessRunnerSpy()

        try await XcodebuildRuntimeDownloader(runner: runner).download(.iOS, buildVersion: nil)

        #expect(runner.requests == [.xcrun(downloadIOS, timeout: ProcessRequest.runtimeDownloadTimeout)])
        #expect(runner.requests.first?.executableURL.path(percentEncoded: false) == "/usr/bin/xcrun")
        #expect(ProcessRequest.runtimeDownloadTimeout == .seconds(21_600))
    }

    @Test(arguments: RuntimePlatform.allCases)
    func passesThePlatformByItsExactName(platform: RuntimePlatform) async throws {
        let runner = ProcessRunnerSpy()

        try await XcodebuildRuntimeDownloader(runner: runner).download(platform, buildVersion: nil)

        #expect(runner.arguments == [["xcodebuild", "-downloadPlatform", platform.rawValue]])
        #expect(["iOS", "watchOS", "tvOS", "visionOS"].contains(platform.rawValue))
    }

    @Test
    func appendsTheValidatedBuildVersion() async throws {
        let runner = ProcessRunnerSpy()
        let version = try #require(RuntimeBuildVersion("18.0"))

        try await XcodebuildRuntimeDownloader(runner: runner).download(.iOS, buildVersion: version)

        #expect(runner.arguments == [downloadIOS + ["-buildVersion", "18.0"]])
    }

    @Test
    func exitCode72MeansTheToolsAreUnavailable() async {
        let runner = ProcessRunnerSpy(responses: [
            downloadIOS: .failure(.commandFailed(exitCode: 72, summary: "")),
        ])

        await #expect(throws: CleanupError.toolUnavailable) {
            try await XcodebuildRuntimeDownloader(runner: runner).download(.iOS, buildVersion: nil)
        }
    }

    @Test
    func xcrunErrorsMeanTheToolsAreUnavailable() async {
        let runner = ProcessRunnerSpy(responses: [
            downloadIOS: .failure(.commandFailed(
                exitCode: 1,
                summary: "xcrun: error: unable to find utility \"xcodebuild\", not a developer tool or in PATH"
            )),
        ])

        await #expect(throws: CleanupError.toolUnavailable) {
            try await XcodebuildRuntimeDownloader(runner: runner).download(.iOS, buildVersion: nil)
        }
    }

    @Test(arguments: [
        CleanupError.commandFailed(exitCode: 69, summary: "You have not agreed to the Xcode license agreements."),
        .commandFailed(exitCode: 1, summary: "xcodebuild: error: unable to download"),
        .timedOut,
    ])
    func otherCommandFailuresAndTimeoutsPassThrough(failure: CleanupError) async {
        let runner = ProcessRunnerSpy(responses: [downloadIOS: .failure(failure)])

        await #expect(throws: failure) {
            try await XcodebuildRuntimeDownloader(runner: runner).download(.iOS, buildVersion: nil)
        }
    }

    /// AC10: the chosen version goes to `-buildVersion`, without a shell (C35).
    @Test
    func downloadsTheChosenVersion() async throws {
        let runner = ProcessRunnerSpy()
        let version = try #require(RuntimeBuildVersion("26.5"))

        try await XcodebuildRuntimeDownloader(runner: runner).download(.iOS, buildVersion: version)

        #expect(runner.requests == [
            .xcrun(downloadIOS + ["-buildVersion", "26.5"], timeout: ProcessRequest.runtimeDownloadTimeout),
        ])
    }

    /// AC11: Xcode refuses a version on the standard output and exits with an error (C35, R9).
    @Test
    func aRefusalOnTheStandardOutputIsAnUnavailableVersion() async throws {
        let runner = ScriptedProcessRunner(
            standardOutput: "Finding content...\niOS 18.0 is not available for download.\n",
            failure: .commandFailed(exitCode: 1, summary: "")
        )

        await #expect(throws: CleanupError.runtimeVersionUnavailable) {
            try await XcodebuildRuntimeDownloader(runner: runner).download(
                .iOS,
                buildVersion: RuntimeBuildVersion("18.0")
            )
        }
    }

    @Test
    func aRefusalOnTheStandardErrorIsAnUnavailableVersion() async {
        let runner = ProcessRunnerSpy(responses: [
            downloadIOS + ["-buildVersion", "17.5"]: .failure(.commandFailed(
                exitCode: 70,
                summary: "2026-11-09 07:00:00.000 xcodebuild[1:2] Note: one\n"
                    + "xcodebuild: error: iOS 17.5 is not available for download."
            )),
        ])

        await #expect(throws: CleanupError.runtimeVersionUnavailable) {
            try await XcodebuildRuntimeDownloader(runner: runner).download(
                .iOS,
                buildVersion: RuntimeBuildVersion("17.5")
            )
        }
    }

    /// A refusal is never an install, even when `xcodebuild` exits with 0.
    @Test
    func aRefusalWithExitZeroIsStillAnUnavailableVersion() async {
        let onStandardOutput = ProcessRunnerSpy(responses: [
            downloadIOS + ["-buildVersion", "18.6"]: .success("iOS 18.6 is not available for download.\n"),
        ])
        let onStandardError = ScriptedProcessRunner(
            standardOutput: "",
            standardError: "iOS 18.6 is not available for download.\n"
        )

        await #expect(throws: CleanupError.runtimeVersionUnavailable) {
            try await XcodebuildRuntimeDownloader(runner: onStandardOutput)
                .download(.iOS, buildVersion: RuntimeBuildVersion("18.6"))
        }

        await #expect(throws: CleanupError.runtimeVersionUnavailable) {
            try await XcodebuildRuntimeDownloader(runner: onStandardError)
                .download(.iOS, buildVersion: RuntimeBuildVersion("18.6"))
        }
    }

    @Test
    func anAlreadyDownloadedRuntimeIsNotARefusal() async throws {
        let runner = ProcessRunnerSpy(responses: [
            downloadIOS: .success("iOS 27.2 is already downloaded, and no downloadable is available.\n"),
        ])

        try await XcodebuildRuntimeDownloader(runner: runner).download(.iOS, buildVersion: nil)
    }

    /// Cancelling after the refusal was printed is still a cancellation.
    @Test
    func aCancellationIsNeverARefusal() async {
        let runner = ScriptedProcessRunner(
            standardOutput: "iOS 18.0 is not available for download.\n",
            failure: nil,
            error: CancellationError()
        )

        await #expect(throws: CancellationError.self) {
            try await XcodebuildRuntimeDownloader(runner: runner).download(
                .iOS,
                buildVersion: RuntimeBuildVersion("18.0")
            )
        }
    }

    /// The progress comes from the real output of `xcodebuild` (C34), step by step.
    @Test
    func reportsTheProgressOfTheRealOutput() async throws {
        let sample = try RuntimeDownloadOutputFixture.tvOSSample()
        let downloadTVOS = ["xcodebuild", "-downloadPlatform", "tvOS"]
        let output = try #require(String(bytes: sample, encoding: .utf8))
        let runner = ProcessRunnerSpy(responses: [downloadTVOS: .success(output)])
        let events = EventCollector()

        var splitter = OutputLineSplitter()

        let expected = (splitter.append(sample) + splitter.finish())
            .compactMap(RuntimeDownloadOutputParser.event(from:))

        try await XcodebuildRuntimeDownloader(runner: runner).download(
            .tvOS,
            buildVersion: nil,
            onProgress: events.append
        )

        #expect(events.all == expected)
        #expect(events.all.count == 27)
        #expect(events.all.first == .preparing)
    }

    @Test
    func unknownOutputReportsNothing() async throws {
        let runner = ProcessRunnerSpy(responses: [downloadIOS: .success("Something new\rDone.\n")])
        let events = EventCollector()

        try await XcodebuildRuntimeDownloader(runner: runner).download(
            .iOS,
            buildVersion: nil,
            onProgress: events.append
        )

        #expect(events.all.isEmpty)
    }

    /// Cancelling the download cancels the runner, which terminates `xcodebuild` (C13).
    @Test(.timeLimit(.minutes(1)))
    func cancellingTheCallerCancelsTheRunner() async {
        let runner = GatedProcessRunner()
        let downloader = XcodebuildRuntimeDownloader(runner: runner)

        var arrivals = runner.arrivals.stream.makeAsyncIterator()

        let download = Task { try await downloader.download(.iOS, buildVersion: nil) }
        _ = await arrivals.next()

        download.cancel()

        await #expect(throws: CancellationError.self) {
            try await download.value
        }
        #expect(runner.wasCancelled)
    }

    // MARK: - Nested Types

    /// Hands its standard output line by line, as `ProcessRunner` does, then answers with the
    /// standard error, or throws.
    nonisolated private struct ScriptedProcessRunner: ProcessRunning {

        // MARK: - Public Properties

        let standardOutput: String

        var standardError = ""
        var failure: CleanupError?
        var error: (any Error & Sendable)?

        // MARK: - Public Methods

        func run(_ request: ProcessRequest) async throws -> ProcessOutput {
            try await run(request) { _ in }
        }

        func run(
            _ request: ProcessRequest,
            onStandardOutputLine: @escaping @Sendable (String) -> Void
        ) throws -> ProcessOutput {
            var splitter = OutputLineSplitter()

            (splitter.append(Data(standardOutput.utf8)) + splitter.finish()).forEach(onStandardOutputLine)

            if let error {
                throw error
            }

            if let failure {
                throw failure
            }

            return ProcessOutput(standardOutput: Data(standardOutput.utf8), standardError: Data(standardError.utf8))
        }

    }

    /// The steps a download reported, in order.
    nonisolated private final class EventCollector: Sendable {

        // MARK: - Public Properties

        var all: [RuntimeDownloadEvent] {
            events.withLock { $0 }
        }

        // MARK: - Private Properties

        private let events = Mutex<[RuntimeDownloadEvent]>([])

        // MARK: - Public Methods

        func append(_ event: RuntimeDownloadEvent) {
            events.withLock { $0.append(event) }
        }

    }

}
