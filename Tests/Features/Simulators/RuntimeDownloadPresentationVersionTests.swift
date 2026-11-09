//
//  RuntimeDownloadPresentationVersionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The runtime download card names a chosen earlier version ("iOS 26.5") wherever it names the
/// platform, and tells when Xcode refuses it (C35, R9, R10, AC11, AC12). Without a version the texts
/// of the C30 and C34 stay as they were.
struct RuntimeDownloadPresentationVersionTests {

    // MARK: - Private Properties

    private let separator = " · "

    // MARK: - Public Methods

    @Test
    func theDownloadNamesTheVersion() throws {
        let run = try run([.iOS, .watchOS], versions: [.iOS: "26.5"])
        let progress = RuntimeDownloadProgress(phase: .downloading(fraction: 0.42), remaining: nil)

        let card = RuntimeDownloadPresentation(state: .downloading(run), progress: progress)

        #expect(card
            .title == String(localized: "Downloading the \("iOS 26.5") runtime… \(percent(0.42)) (\(1) of \(2))"))
        #expect(card.caption.hasPrefix(String(localized: "Queued: \("watchOS")")))
    }

    @Test
    func theQueueNamesTheQueuedVersion() throws {
        var run = try run([.iOS, .watchOS], versions: [.watchOS: "26.5"])

        run.record(.installed, for: .iOS)

        let card = RuntimeDownloadPresentation(state: .downloading(run))
        let parts = [String(localized: "\("iOS") installed")]

        #expect(card.title == String(localized: "Downloading the \("watchOS 26.5") runtime… (\(2) of \(2))"))
        #expect(card
            .caption ==
            String(localized: "\(parts.joined(separator: separator)). Keep CleanerXcode open until it finishes."))

        let first = try RuntimeDownloadPresentation(state: .downloading(self.run(
            [.iOS, .watchOS],
            versions: [.watchOS: "26.5"]
        )))

        #expect(first.caption.hasPrefix(String(localized: "Queued: \("watchOS 26.5")")))
    }

    @Test
    func anInstalledVersionIsNamed() throws {
        var one = try run([.iOS], versions: [.iOS: "26.5"])
        var two = try run([.iOS, .visionOS], versions: [.iOS: "26.5"])

        one.record(.installed, for: .iOS)
        two.recordRemaining(.installed)

        let names = ["iOS 26.5", "visionOS"].formatted(.list(type: .and))

        #expect(RuntimeDownloadPresentation(state: .finished(one))
            .title == String(localized: "\("iOS 26.5") runtime installed"))
        #expect(RuntimeDownloadPresentation(state: .finished(two))
            .caption == String(localized: "\(names) now show in the runtimes list."))
    }

    /// AC11: the refusal reads "Not available for the selected Xcode", with "Try again".
    @Test
    func aRefusedVersionTellsWhy() throws {
        var run = try run([.iOS], versions: [.iOS: "26.5"])

        run.record(.failed(.runtimeVersionUnavailable), for: .iOS)

        let card = RuntimeDownloadPresentation(state: .finished(run))

        #expect(card.title == String(localized: "Could not download the \("iOS 26.5") runtime"))
        #expect(card.caption == String(localized: "Not available for the selected Xcode"))
        #expect(CleanupError.runtimeVersionUnavailable.summary.key == "Not available for the selected Xcode")
        #expect(card.action == .retry)
        #expect(card.tint == .orange)
    }

    @Test
    func eachFinishedFragmentNamesItsVersion() throws {
        var run = try run([.iOS, .watchOS, .tvOS], versions: [.iOS: "26.5", .watchOS: "26.5"])

        run.record(.installed, for: .iOS)
        run.record(.failed(.runtimeVersionUnavailable), for: .watchOS)
        run.recordRemaining(.notDownloaded)

        let card = RuntimeDownloadPresentation(state: .finished(run))
        let expected = [
            String(localized: "\("iOS 26.5") installed"),
            "watchOS 26.5: " + String(localized: "Not available for the selected Xcode"),
            String(localized: "\("tvOS") was not downloaded"),
        ]

        #expect(card.caption == expected.joined(separator: separator))
    }

    /// B3: the card previews of the C35 frames (F6, F7) show the version.
    @Test
    func theCardPreviewsOfTheFramesNameTheVersion() {
        let downloading = RuntimeDownloadPresentation(
            state: RuntimeDownloadPreviewFixtures.downloadingEarlierVersion,
            progress: RuntimeDownloadPreviewFixtures.fortyTwoPercent
        )
        let refused = RuntimeDownloadPresentation(state: RuntimeDownloadPreviewFixtures.earlierVersionUnavailable)

        #expect(downloading.title == String(localized: "Downloading the \("iOS 26.5") runtime… \(percent(0.42))"))
        #expect(refused.title == String(localized: "Could not download the \("iOS 26.5") runtime"))
        #expect(refused.caption == String(localized: "Not available for the selected Xcode"))
    }

    // MARK: - Private Methods

    private func run(_ platforms: [RuntimePlatform], versions: [RuntimePlatform: String]) throws -> RuntimeDownloadRun {
        RuntimeDownloadRun(platforms, versions: versions.compactMapValues(RuntimeBuildVersion.init))
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

}
