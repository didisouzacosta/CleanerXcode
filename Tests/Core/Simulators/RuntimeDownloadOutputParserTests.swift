//
//  RuntimeDownloadOutputParserTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The lines of `xcodebuild -downloadPlatform` read as download steps (C34). The output is not
/// documented, so the real sample pins the format and anything else is ignored.
struct RuntimeDownloadOutputParserTests {

    // MARK: - Public Methods

    @Test
    func theRealSampleReadsAsPreparingThenDownloading() throws {
        let events = try sampleLines().map(RuntimeDownloadOutputParser.event(from:))
        let amounts = events.compactMap { event -> RuntimeDownloadAmount? in
            guard case let .downloading(amount) = event else { return nil }

            return amount
        }

        #expect(events.count == 29)
        #expect(Array(events.prefix(4)) == [.preparing, nil, .preparing, .preparing])
        #expect(events.last == .some(nil), "\"Download was cancelled.\" is not a step.")
        #expect(events.count { $0 == nil } == 2)
        #expect(amounts.count == 24)
        #expect(amounts.first == RuntimeDownloadAmount(fraction: 0, receivedBytes: 66_000, totalBytes: 3_760_000_000))
        #expect(amounts.last?.receivedBytes == 27_300_000)
        #expect(amounts.last?.totalBytes == 3_760_000_000)
        #expect(abs((amounts.last?.fraction ?? 0) - 0.007) < 0.000_001)
        #expect(zip(amounts, amounts.dropFirst()).allSatisfy { $0.fraction <= $1.fraction })
        #expect(zip(amounts, amounts.dropFirst()).allSatisfy { $0.receivedBytes <= $1.receivedBytes })
    }

    @Test(arguments: [
        (
            "Downloading iOS 27.2 Simulator (24C101): 42.5% (1.6 GB of 3.76 GB)",
            RuntimeDownloadAmount(fraction: 0.425, receivedBytes: 1_600_000_000, totalBytes: 3_760_000_000)
        ),
        (
            "Downloading tvOS 27.2 Simulator (24K150) (arm64): 0,7% (26 MB of 3,76 GB)  ",
            RuntimeDownloadAmount(fraction: 0.007, receivedBytes: 26_000_000, totalBytes: 3_760_000_000)
        ),
        (
            "Downloading visionOS 27.2 Simulator (24N310): 0,7\u{00A0}% (27,3\u{00A0}Mo of 3,76\u{00A0}Go)",
            RuntimeDownloadAmount(fraction: 0.007, receivedBytes: 27_300_000, totalBytes: 3_760_000_000)
        ),
        (
            "Downloading watchOS 27.2 Simulator (24R412): 0.0% (512 bytes of 3.4 GB)",
            RuntimeDownloadAmount(fraction: 0, receivedBytes: 512, totalBytes: 3_400_000_000)
        ),
        (
            "Downloading Big Runtime (Beta 2) (arm64): 50% (0.5 TB of 1 TB)",
            RuntimeDownloadAmount(fraction: 0.5, receivedBytes: 500_000_000_000, totalBytes: 1_000_000_000_000)
        ),
        (
            "Downloading iOS 27.2 Simulator: 12,5% (1\u{202F}234,5 MB of 9\u{202F}876,5 MB)",
            RuntimeDownloadAmount(fraction: 0.125, receivedBytes: 1_234_500_000, totalBytes: 9_876_500_000)
        ),
    ])
    func readsTheAmountInAnyLocaleAndUnit(line: String, amount: RuntimeDownloadAmount) throws {
        let event = try #require(RuntimeDownloadOutputParser.event(from: line))

        guard case let .downloading(read) = event else {
            Issue.record("Expected a download step, got \(event)")
            return
        }

        #expect(abs(read.fraction - amount.fraction) < 0.000_001)
        #expect(read.receivedBytes == amount.receivedBytes)
        #expect(read.totalBytes == amount.totalBytes)
    }

    @Test
    func aFinishedDownloadMeansTheImportStarts() {
        let line = "Downloading tvOS 27.2 Simulator (24K150) (arm64): 100,0% (3,76 GB of 3,76 GB)"

        #expect(RuntimeDownloadOutputParser.event(from: line) == .installing)
    }

    /// Not seen in the sample: these strings come from the Xcode3Core binary.
    @Test(arguments: [
        ("Done downloading: tvOS 27.2 Simulator (24K150)", RuntimeDownloadEvent.installing),
        ("Beginning asset import...", .installing),
        ("Done importing: tvOS 27.2 Simulator (24K150)", .completed),
        ("Finding content...", .preparing),
        ("Downloading tvOS 27.2 Simulator (24K150) (arm64):", .preparing),
        ("Downloading tvOS 27.2 Simulator (24K150) (arm64): Preparing to download...", .preparing),
    ])
    func readsTheSyntheticSteps(line: String, event: RuntimeDownloadEvent) {
        #expect(RuntimeDownloadOutputParser.event(from: line) == event)
    }

    @Test(arguments: [
        "Downloading iOS: 1% (1 GB of 0 GB)",
        "Downloading iOS: 1% (5 GB of 3 GB)",
        "Downloading iOS: 1% (Zero KB of 3 GB)",
        "Downloading iOS: % (1 GB of 3 GB)",
        "Downloading iOS: 101% (3 GB of 3 GB)",
        "Downloading iOS: 1% (1 XB of 3 GB)",
        "Downloading iOS: 1%",
        "Downloading iOS",
        "",
        "   ",
        "Automatically resolved architecture variant for platform tvOS as 'arm64'.",
        "Download was cancelled.",
    ])
    func ignoresWhatItDoesNotRecognize(line: String) {
        #expect(RuntimeDownloadOutputParser.event(from: line) == nil)
    }

    @Test(arguments: [
        ("3,76", 3.76),
        ("3.76", 3.76),
        ("1,234.5", 1_234.5),
        ("1.234,5", 1_234.5),
        ("1 234,5", 1_234.5),
        ("1,234", 1_234),
        ("1,234,567", 1_234_567),
        ("12,3", 12.3),
        ("0,7", 0.7),
        ("66", 66),
    ])
    func readsNumbersWithEitherSeparator(text: String, value: Double) throws {
        let number = try #require(RuntimeDownloadOutputParser.number(from: text))

        #expect(abs(number - value) < 0.000_001)
    }

    @Test(arguments: ["abc", "", "1,2,3.4.5", "-1", "1e3"])
    func rejectsWhatIsNotANumber(text: String) {
        #expect(RuntimeDownloadOutputParser.number(from: text) == nil)
    }

    /// Xcode's refusal of a version it cannot download (C35, R9), told apart from "already downloaded".
    @Test(arguments: [
        ("iOS 18.0 is not available for download.", true),
        ("xcodebuild: error: iOS 17.5 is not available for download.", true),
        ("  watchOS 11.0 is not available for download.\u{00A0}", true),
        ("iOS 26.0 is already downloaded.", false),
        ("iOS 26.0 is already downloaded, and no downloadable is available.", false),
        ("Downloading iOS 26.0 Simulator (23A343) (arm64): 0,1% (10,6 MB of 7,99 GB)", false),
        ("is not available for download", false),
        ("", false),
    ])
    func recognizesTheRefusalOfAVersion(line: String, isRefusal: Bool) {
        #expect(RuntimeDownloadOutputParser.isUnavailableVersion(line) == isRefusal)
        #expect(RuntimeDownloadOutputParser.event(from: line) == nil || !isRefusal)
    }

    // MARK: - Private Methods

    private func sampleLines() throws -> [String] {
        var splitter = OutputLineSplitter()

        let sample = try RuntimeDownloadOutputFixture.tvOSSample()

        return splitter.append(sample) + splitter.finish()
    }

}
