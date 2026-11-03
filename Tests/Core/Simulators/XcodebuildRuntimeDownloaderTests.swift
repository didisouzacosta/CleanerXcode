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
