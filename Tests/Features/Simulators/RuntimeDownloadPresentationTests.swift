//
//  RuntimeDownloadPresentationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The runtime download card of the "Simulators and runtimes" page (C30, A1 section 4): the symbol,
/// color, texts and action of each state, for one runtime and for a queue.
struct RuntimeDownloadPresentationTests {

    // MARK: - Private Properties

    private let keepOpen = String(localized: "This can take a while. Keep CleanerXcode open until it finishes.")
    private let separator = " · "

    // MARK: - Public Methods

    @Test
    func idleOffersToChooseThePlatforms() {
        let card = RuntimeDownloadPresentation(state: .idle)

        #expect(card.systemImage == "arrow.down.circle")
        #expect(card.tint == .secondary)
        #expect(card.title == String(localized: "Download runtimes"))
        #expect(card.caption == String(localized: "Choose the platforms · several GB each"))
        #expect(!card.showsProgress)
        #expect(card.action == .choose)
        #expect(card.action?.title.key == "Choose…")
    }

    @Test
    func oneDownloadKeepsTheSingleRuntimeTexts() {
        let card = RuntimeDownloadPresentation(state: .downloading(RuntimeDownloadRun([.iOS])))

        #expect(card.systemImage == "arrow.down.circle")
        #expect(card.tint == .accent)
        #expect(card.title == String(localized: "Downloading the \("iOS") runtime…"))
        #expect(card.caption == keepOpen)
        #expect(card.showsProgress)
        #expect(card.action == .cancel)
        #expect(card.action?.title.key == "Cancel")
    }

    @Test
    func aQueueShowsThePositionWhatFinishedAndWhatIsQueued() {
        var run = RuntimeDownloadRun([.iOS, .watchOS, .visionOS])

        run.record(.installed, for: .iOS)

        let card = RuntimeDownloadPresentation(state: .downloading(run))
        let parts = [String(localized: "\("iOS") installed"), String(localized: "Queued: \("visionOS")")]

        #expect(card.title == String(localized: "Downloading the \("watchOS") runtime… (\(2) of \(3))"))
        #expect(card
            .caption ==
            String(localized: "\(parts.joined(separator: separator)). Keep CleanerXcode open until it finishes."))
        #expect(card.showsProgress)
        #expect(card.action == .cancel)
    }

    @Test
    func theFirstOfAQueueListsTheRestAsQueued() {
        let card = RuntimeDownloadPresentation(state: .downloading(RuntimeDownloadRun([.tvOS, .iOS])))

        #expect(card.title == String(localized: "Downloading the \("iOS") runtime… (\(1) of \(2))"))
        #expect(card
            .caption ==
            String(localized: "\(String(localized: "Queued: \("tvOS")")). Keep CleanerXcode open until it finishes."))
    }

    /// Between the last download and the end of the queue, the card still names the last platform
    /// and lists what finished.
    @Test
    func theEndOfAQueueStillListsWhatFinished() {
        var run = RuntimeDownloadRun([.iOS, .tvOS])

        run.record(.installed, for: .iOS)
        run.record(.installed, for: .tvOS)

        let card = RuntimeDownloadPresentation(state: .downloading(run))

        #expect(card.title == String(localized: "Downloading the \("tvOS") runtime… (\(2) of \(2))"))
        #expect(card.caption.contains(String(localized: "\("iOS") installed")))
    }

    @Test
    func oneInstalledRuntimeNeedsNoAction() {
        var run = RuntimeDownloadRun([.iOS])

        run.record(.installed, for: .iOS)

        let card = RuntimeDownloadPresentation(state: .finished(run))

        #expect(card.systemImage == "checkmark.circle.fill")
        #expect(card.tint == .green)
        #expect(card.title == String(localized: "\("iOS") runtime installed"))
        #expect(card.caption == String(localized: "It now shows in the runtimes list."))
        #expect(!card.showsProgress)
        #expect(card.action == nil)
    }

    @Test
    func severalInstalledRuntimesAreCountedAndNamed() {
        var run = RuntimeDownloadRun([.watchOS, .visionOS])

        run.record(.installed, for: .watchOS)
        run.record(.installed, for: .visionOS)

        let card = RuntimeDownloadPresentation(state: .finished(run))
        let names = ["watchOS", "visionOS"].formatted(.list(type: .and))

        #expect(card.systemImage == "checkmark.circle.fill")
        #expect(card.tint == .green)
        #expect(card.title == String(localized: "\(2) runtimes installed"))
        #expect(card.caption == String(localized: "\(names) now show in the runtimes list."))
        #expect(card.action == nil)
    }

    @Test
    func oneFailedRuntimeTellsWhyAndOffersToTryAgain() {
        var run = RuntimeDownloadRun([.iOS])

        run.record(.failed(.timedOut), for: .iOS)

        let card = RuntimeDownloadPresentation(state: .finished(run))

        #expect(card.systemImage == "exclamationmark.triangle.fill")
        #expect(card.tint == .orange)
        #expect(card.title == String(localized: "Could not download the \("iOS") runtime"))
        #expect(card.caption == String(localized: CleanupError.timedOut.summary))
        #expect(!card.showsProgress)
        #expect(card.action == .retry)
        #expect(card.action?.title.key == "Try again")
    }

    @Test
    func aPartialFailureCountsTheFailuresAndListsEachPlatform() {
        var run = RuntimeDownloadRun([.watchOS, .visionOS])

        run.record(.installed, for: .watchOS)
        run.record(.failed(.timedOut), for: .visionOS)

        let card = RuntimeDownloadPresentation(state: .finished(run))
        let parts = [
            String(localized: "\("watchOS") installed"),
            "visionOS: " + String(localized: CleanupError.timedOut.summary),
        ]

        #expect(card.tint == .orange)
        #expect(card.title == String(localized: "\(1) of \(2) runtimes were not downloaded"))
        #expect(card.caption == parts.joined(separator: separator))
        #expect(card.action == .retry)
    }

    @Test
    func missingToolsAreTheReasonOfEveryFailure() {
        var run = RuntimeDownloadRun([.iOS, .tvOS])

        run.recordRemaining(.failed(.toolUnavailable))

        let card = RuntimeDownloadPresentation(state: .finished(run))
        let summary = String(localized: CleanupError.toolUnavailable.summary)

        #expect(card.title == String(localized: "\(2) of \(2) runtimes were not downloaded"))
        #expect(card.caption == ["iOS: \(summary)", "tvOS: \(summary)"].joined(separator: separator))
        #expect(card.action == .retry)
    }

    @Test
    func cancellingBeforeAnythingFinishedIsNeutral() {
        var run = RuntimeDownloadRun([.iOS])

        run.recordRemaining(.notDownloaded)

        let card = RuntimeDownloadPresentation(state: .finished(run))

        #expect(card.systemImage == "xmark.circle")
        #expect(card.tint == .secondary)
        #expect(card.title == String(localized: "Download cancelled"))
        #expect(card.caption == String(localized: "No runtime was installed."))
        #expect(card.action == .choose)
    }

    @Test
    func cancellingAfterAnInstallListsEachPlatform() {
        var run = RuntimeDownloadRun([.watchOS, .visionOS])

        run.record(.installed, for: .watchOS)
        run.recordRemaining(.notDownloaded)

        let card = RuntimeDownloadPresentation(state: .finished(run))
        let parts = [String(localized: "\("watchOS") installed"), String(localized: "\("visionOS") was not downloaded")]

        #expect(card.systemImage == "xmark.circle")
        #expect(card.title == String(localized: "Download cancelled"))
        #expect(card.caption == parts.joined(separator: separator))
        #expect(card.action == .choose)
    }

}
