//
//  RuntimeDownloadProgressTrackerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The download steps turned into what the card shows, published at most about once a second
/// except when the phase changes (C34). The instants are synthetic, so nothing waits.
struct RuntimeDownloadProgressTrackerTests {

    // MARK: - Private Properties

    private let base = ContinuousClock.now
    private let total: Int64 = 3_760_000_000

    // MARK: - Public Methods

    @Test
    func theFirstStepPublishesAtOnce() {
        var tracker = RuntimeDownloadProgressTracker()

        #expect(tracker.receive(.preparing, at: base) == RuntimeDownloadProgress(phase: .preparing, remaining: nil))
    }

    @Test
    func aSecondAmountInTheSameSecondWaits() {
        var tracker = RuntimeDownloadProgressTracker()

        let first = tracker.receive(downloading(0.001, 3_600_000), at: base)
        let second = tracker.receive(downloading(0.002, 6_700_000), at: base + .milliseconds(500))
        let third = tracker.receive(downloading(0.003, 9_800_000), at: base + .seconds(1))

        #expect(first?.phase == .downloading(fraction: 0.001))
        #expect(second == nil)
        #expect(third?.phase == .downloading(fraction: 0.003))
    }

    @Test
    func aNewPhasePublishesAtOnce() {
        var tracker = RuntimeDownloadProgressTracker()

        _ = tracker.receive(downloading(0.999, 3_750_000_000), at: base)

        #expect(tracker.receive(.installing, at: base + .milliseconds(200))?.phase == .installing)
        #expect(
            tracker.receive(.completed, at: base + .milliseconds(400)) == nil,
            "Completed also shows as installing."
        )
    }

    @Test
    func aRepeatedLinePublishesNothing() {
        var tracker = RuntimeDownloadProgressTracker()

        _ = tracker.receive(downloading(0.001, 3_600_000), at: base)

        #expect(tracker.receive(downloading(0.001, 3_600_000), at: base + .seconds(2)) == nil)
    }

    /// The real sample, at about one line a second, with the gap of the chunks left out of it.
    @Test
    func theRealSampleShowsTheTimeLeftAfterTenSeconds() throws {
        var tracker = RuntimeDownloadProgressTracker()

        var published: [(second: Int, progress: RuntimeDownloadProgress)] = []

        for (second, event) in try timedSampleEvents() {
            if let progress = tracker.receive(event, at: base + .seconds(second)) {
                published.append((second, progress))
            }
        }

        let estimates = published.compactMap { item in
            item.progress.remaining.map { (item.second, $0) }
        }

        #expect(published.first?.progress.phase == .preparing)
        #expect(!estimates.isEmpty)
        #expect(estimates.allSatisfy { $0.0 >= 10 })

        for (_, remaining) in estimates {
            guard case let .hoursAndMinutes(minutes) = remaining else {
                Issue.record("Expected hours and minutes, got \(remaining)")
                continue
            }

            #expect((60...180).contains(minutes))
        }
    }

    // MARK: - Private Methods

    private func downloading(_ fraction: Double, _ received: Int64) -> RuntimeDownloadEvent {
        .downloading(RuntimeDownloadAmount(fraction: fraction, receivedBytes: received, totalBytes: total))
    }

    /// One progress line a second; the 24 chunks left out of the sample come after the 12th one.
    private func timedSampleEvents() throws -> [(Int, RuntimeDownloadEvent)] {
        var splitter = OutputLineSplitter()

        let sample = try RuntimeDownloadOutputFixture.tvOSSample()
        let events = (splitter.append(sample) + splitter.finish()).compactMap(RuntimeDownloadOutputParser.event(from:))

        var progressLines = 0

        return events.map { event in
            guard case .downloading = event else { return (0, event) }

            defer { progressLines += 1 }

            return (progressLines < 12 ? progressLines : progressLines + 24, event)
        }
    }

}
