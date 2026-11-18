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

    /// iOS installed, watchOS downloading, visionOS queued.
    private var queue: RuntimeDownloadRun {
        var run = RuntimeDownloadRun([.iOS, .watchOS, .visionOS])

        run.record(.installed, for: .iOS)
        return run
    }

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

    /// Between the last install and the end of the queue the list is updated, which takes a few
    /// seconds: the card says so instead of "Downloading…" (N5, C34), and Cancel stays.
    @Test(arguments: [[RuntimePlatform.iOS], [.iOS, .tvOS]])
    func theListingAfterTheLastInstallHasItsOwnText(platforms: [RuntimePlatform]) {
        var run = RuntimeDownloadRun(platforms)

        run.recordRemaining(.installed)

        let card = RuntimeDownloadPresentation(state: .downloading(run), progress: nil)

        #expect(card.title == String(localized: "Updating the runtimes list…"))
        #expect(card.indicator == .indeterminate(label: String(localized: "Updating the runtimes list…")))
        #expect(card.systemImage == "arrow.down.circle")
        #expect(card.tint == .accent)
        #expect(card.action == .cancel)

        if platforms.count == 1 {
            #expect(card.caption == keepOpen)
        } else {
            #expect(card.caption.contains(String(localized: "\("iOS") installed")))
            #expect(card.caption.contains(String(localized: "\("tvOS") installed")))
        }
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

    // MARK: - Progress (C34)

    /// Without a recognized line, or while preparing, the card is exactly the C30 one.
    @Test(arguments: [nil, RuntimeDownloadProgress(phase: .preparing, remaining: nil)])
    func withoutProgressTheCardKeepsTheC30Texts(progress: RuntimeDownloadProgress?) {
        let run = RuntimeDownloadRun([.iOS])
        let card = RuntimeDownloadPresentation(state: .downloading(run), progress: progress)

        #expect(card.title == String(localized: "Downloading the \("iOS") runtime…"))
        #expect(card.caption == keepOpen)
        #expect(card.indicator == .indeterminate(label: String(localized: "Downloading")))
        #expect(card.showsProgress)
        #expect(card.action == .cancel)
    }

    @Test
    func theDownloadShowsThePercentageAndABar() {
        let card = RuntimeDownloadPresentation(
            state: .downloading(RuntimeDownloadRun([.iOS])),
            progress: downloading(0.03)
        )
        let percent = percent(0.03)

        #expect(card.title == String(localized: "Downloading the \("iOS") runtime… \(percent)"))
        #expect(card.caption == keepOpen)
        #expect(card.indicator == .determinate(fraction: 0.03, valueDescription: percent))
        #expect(card.showsProgress)
        #expect(card.action == .cancel)
        #expect(card.systemImage == "arrow.down.circle")
        #expect(card.tint == .accent)
    }

    @Test
    func theTimeLeftLeadsTheCaption() {
        let remaining = RuntimeDownloadRemaining.minutes(12)
        let card = RuntimeDownloadPresentation(
            state: .downloading(RuntimeDownloadRun([.iOS])),
            progress: downloading(0.42, remaining: remaining)
        )
        let percent = percent(0.42)

        #expect(card.title == String(localized: "Downloading the \("iOS") runtime… \(percent)"))
        #expect(card.caption == String(localized: "\(remaining.text). Keep CleanerXcode open until it finishes."))
        #expect(card.indicator == .determinate(fraction: 0.42, valueDescription: "\(percent), \(remaining.text)"))
    }

    @Test
    func aQueueShowsTheProgressOfTheCurrentPlatform() {
        let remaining = RuntimeDownloadRemaining.minutes(12)
        let card = RuntimeDownloadPresentation(
            state: .downloading(queue),
            progress: downloading(0.42, remaining: remaining)
        )
        let parts = [
            remaining.text,
            String(localized: "\("iOS") installed"),
            String(localized: "Queued: \("visionOS")"),
        ]

        #expect(card
            .title == String(localized: "Downloading the \("watchOS") runtime… \(percent(0.42)) (\(2) of \(3))"))
        #expect(card
            .caption ==
            String(localized: "\(parts.joined(separator: separator)). Keep CleanerXcode open until it finishes."))
    }

    @Test
    func aQueueWithoutTheTimeLeftKeepsTheC30Caption() {
        let card = RuntimeDownloadPresentation(state: .downloading(queue), progress: downloading(0.42))
        let parts = [String(localized: "\("iOS") installed"), String(localized: "Queued: \("visionOS")")]

        #expect(card
            .caption ==
            String(localized: "\(parts.joined(separator: separator)). Keep CleanerXcode open until it finishes."))
        #expect(card.indicator == .determinate(fraction: 0.42, valueDescription: percent(0.42)))
    }

    @Test
    func installingShowsAnIndeterminateProgress() {
        let installing = RuntimeDownloadProgress(phase: .installing, remaining: nil)
        let one = RuntimeDownloadPresentation(state: .downloading(RuntimeDownloadRun([.iOS])), progress: installing)
        let several = RuntimeDownloadPresentation(state: .downloading(queue), progress: installing)

        #expect(one.title == String(localized: "Installing the \("iOS") runtime…"))
        #expect(one.caption == keepOpen)
        #expect(one.indicator == .indeterminate(label: String(localized: "Installing")))
        #expect(one.action == .cancel)
        #expect(several.title == String(localized: "Installing the \("watchOS") runtime… (\(2) of \(3))"))
        #expect(several.indicator == .indeterminate(label: String(localized: "Installing")))
    }

    /// Never "100%" before the end, and never a rounding slip below the real value.
    @Test(arguments: [(0.999, 0.99), (0.29, 0.29), (0.007, 0.0), (1.0, 1.0)])
    func thePercentageIsRoundedDown(fraction: Double, shown: Double) {
        let card = RuntimeDownloadPresentation(
            state: .downloading(RuntimeDownloadRun([.iOS])),
            progress: downloading(fraction)
        )

        #expect(card.indicator == .determinate(fraction: fraction, valueDescription: percent(shown)))
    }

    @Test
    func theProgressIsIgnoredOutsideADownload() {
        var run = RuntimeDownloadRun([.iOS])

        run.record(.installed, for: .iOS)

        let idle = RuntimeDownloadPresentation(state: .idle, progress: downloading(0.42))
        let finished = RuntimeDownloadPresentation(state: .finished(run), progress: downloading(0.42))

        #expect(idle.title == String(localized: "Download runtimes"))
        #expect(idle.indicator == .none)
        #expect(!idle.showsProgress)
        #expect(finished.title == String(localized: "\("iOS") runtime installed"))
        #expect(finished.indicator == .none)
    }

    // MARK: - Private Methods

    private func downloading(
        _ fraction: Double,
        remaining: RuntimeDownloadRemaining? = nil
    ) -> RuntimeDownloadProgress {
        RuntimeDownloadProgress(phase: .downloading(fraction: fraction), remaining: remaining)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

}
