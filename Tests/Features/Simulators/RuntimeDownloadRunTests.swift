//
//  RuntimeDownloadRunTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Testing
@testable import CleanerXcode

/// The download queue (C30, A1): always in the order of `RuntimePlatform.allCases`, one at a time.
struct RuntimeDownloadRunTests {

    // MARK: - Public Methods

    @Test
    func followsThePlatformOrderWhateverTheSelectionOrderAndDropsRepeats() {
        let run = RuntimeDownloadRun([.visionOS, .iOS, .watchOS, .iOS])

        #expect(run.platforms == [.iOS, .watchOS, .visionOS])
        #expect(run.current == .iOS)
        #expect(run.position == 1)
        #expect(run.queued == [.watchOS, .visionOS])
        #expect(run.installed.isEmpty)
        #expect(run.failed.isEmpty)
        #expect(run.notDownloaded.isEmpty)
        #expect(!run.isCancelled)
    }

    @Test
    func recordingMovesTheCurrentPlatformForward() {
        var run = RuntimeDownloadRun([.iOS, .watchOS, .visionOS])

        run.record(.installed, for: .iOS)

        #expect(run.current == .watchOS)
        #expect(run.position == 2)
        #expect(run.queued == [.visionOS])
        #expect(run.finished == [.iOS])

        run.record(.failed(.timedOut), for: .watchOS)
        run.record(.installed, for: .visionOS)

        #expect(run.current == nil)
        #expect(run.position == 3)
        #expect(run.queued.isEmpty)
        #expect(run.installed == [.iOS, .visionOS])
        #expect(run.failed == [RuntimeDownloadRun.Failure(platform: .watchOS, failure: .timedOut)])
        #expect(!run.isCancelled)
    }

    @Test
    func recordingTheRemainingOnesLeavesTheFinishedAlone() {
        var run = RuntimeDownloadRun([.iOS, .watchOS, .tvOS])

        run.record(.installed, for: .iOS)
        run.recordRemaining(.notDownloaded)

        #expect(run.installed == [.iOS])
        #expect(run.notDownloaded == [.watchOS, .tvOS])
        #expect(run.isCancelled)
        #expect(run.current == nil)
        #expect(run.outcomes[.iOS] == .installed)
    }

    @Test
    func aPlatformOutsideTheQueueIsIgnored() {
        var run = RuntimeDownloadRun([.iOS])

        run.record(.installed, for: .tvOS)

        #expect(run.outcomes.isEmpty)
        #expect(run.current == .iOS)
    }

}
