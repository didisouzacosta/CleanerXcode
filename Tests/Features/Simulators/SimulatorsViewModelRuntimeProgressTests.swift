//
//  SimulatorsViewModelRuntimeProgressTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The progress of the runtime being downloaded (C34): only the current platform's, cleared between
/// platforms and at the end; without a recognized line the card stays indeterminate, as in the C30.
struct SimulatorsViewModelRuntimeProgressTests {

    // MARK: - Private Properties

    private let fortyTwoPercent = RuntimeDownloadEvent.downloading(
        RuntimeDownloadAmount(fraction: 0.42, receivedBytes: 1_580_000_000, totalBytes: 3_760_000_000)
    )

    private var installedRuntime: SimulatorRuntime {
        SimulatorRuntime(
            identifier: "R1",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-1",
            version: "27.1",
            build: "24A1",
            platformIdentifier: "com.apple.platform.iphonesimulator",
            sizeBytes: 7_000,
            lastUsedAt: nil,
            isDeletable: true,
            state: "Ready",
            kind: "Patchable Cryptex Disk Image"
        )
    }

    // MARK: - Public Methods

    @Test(.timeLimit(.minutes(1)))
    func theProgressOfTheCurrentDownloadIsPublishedAndClearedAtTheEnd() async {
        let downloader = RuntimeDownloaderSpy(behavior: .hold)
        let viewModel = makeViewModel(downloader: downloader)
        await viewModel.load()

        downloader.setProgress([fortyTwoPercent], for: .iOS)
        select([.iOS], in: viewModel)

        let downloading = Task { await viewModel.confirmRuntimeDownload() }

        await waitUntil { viewModel.runtimeDownloadProgress != nil }

        #expect(viewModel.runtimeDownloadProgress?.phase == .downloading(fraction: 0.42))
        #expect(viewModel.runtimeDownloadProgress?.remaining == nil)

        downloader.release()
        await downloading.value

        #expect(viewModel.runtimeDownload.isFinished)
        #expect(viewModel.runtimeDownloadProgress == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func eachPlatformHasItsOwnProgress() async {
        let downloader = RuntimeDownloaderSpy(behaviors: [.watchOS: .hold])
        let viewModel = makeViewModel(downloader: downloader)
        await viewModel.load()

        downloader.setProgress([fortyTwoPercent], for: .iOS)
        select([.iOS, .watchOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }

        #expect(await started.next() == .iOS)
        #expect(await started.next() == .watchOS)
        #expect(viewModel.runtimeDownloadProgress == nil, "The iOS progress does not carry over.")

        downloader.release()
        await downloading.value

        #expect(viewModel.runtimeDownloadProgress == nil)
    }

    /// Without a recognized line the card stays as in the C30.
    @Test(.timeLimit(.minutes(1)))
    func withoutProgressTheCardStaysIndeterminate() async {
        let downloader = RuntimeDownloaderSpy(behavior: .hold)
        let viewModel = makeViewModel(downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await started.next()

        let card = RuntimeDownloadPresentation(
            state: viewModel.runtimeDownload,
            progress: viewModel.runtimeDownloadProgress
        )

        #expect(viewModel.runtimeDownloadProgress == nil)
        #expect(card.indicator == .indeterminate(label: String(localized: "Downloading")))

        downloader.release()
        await downloading.value
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingClearsTheProgressAndKeepsTheC30Ending() async {
        let service = SimulatorsServiceSpy(runtimes: [installedRuntime])
        let downloader = RuntimeDownloaderSpy(behavior: .holdUntilCancelled)
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        let listings = service.listingCount

        downloader.setProgress([fortyTwoPercent], for: .iOS)
        select([.iOS], in: viewModel)

        let downloading = Task { await viewModel.confirmRuntimeDownload() }

        await waitUntil { viewModel.runtimeDownloadProgress != nil }

        viewModel.cancelRuntimeDownload()
        await downloading.value

        guard case let .finished(run) = viewModel.runtimeDownload else {
            Issue.record("Expected a finished queue, got \(viewModel.runtimeDownload)")
            return
        }

        #expect(downloader.wasCancelled)
        #expect(run.isCancelled)
        #expect(run.notDownloaded == [.iOS])
        #expect(viewModel.runtimeDownloadProgress == nil)
        #expect(service.listingCount == listings + 1, "One reload after the cancelled queue.")
        #expect(viewModel.phase == .loaded)
    }

    /// The tracker publishes the first step at once, even with the clock standing still.
    @Test(.timeLimit(.minutes(1)))
    func theFirstStepIsPublishedWithTheInjectedClock() async {
        let clock = ManualClock()
        let downloader = RuntimeDownloaderSpy(behavior: .hold)
        let viewModel = SimulatorsViewModel(
            simulators: SimulatorsServiceSpy(runtimes: [installedRuntime]),
            downloader: downloader,
            versionSource: InertRuntimeVersionSource(),
            analytics: AnalyticsStub(),
            now: { clock.now }
        )
        await viewModel.load()

        downloader.setProgress([.installing], for: .iOS)
        select([.iOS], in: viewModel)

        let downloading = Task { await viewModel.confirmRuntimeDownload() }

        await waitUntil { viewModel.runtimeDownloadProgress != nil }

        #expect(viewModel.runtimeDownloadProgress == RuntimeDownloadProgress(phase: .installing, remaining: nil))

        downloader.release()
        await downloading.value
    }

    /// After the last install the list is updated before the queue ends: the card says so (N5), and
    /// a Cancel then only ends the queue once the listing is done, keeping the install.
    @Test(.timeLimit(.minutes(1)))
    func theListingAfterTheLastInstallHasItsOwnText() async {
        let service = SimulatorsServiceSpy(runtimes: [installedRuntime])
        let viewModel = makeViewModel(service)
        await viewModel.load()

        select([.iOS], in: viewModel)
        service.holdNextListing()

        var listings = service.listingHeld.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await listings.next()

        let card = RuntimeDownloadPresentation(
            state: viewModel.runtimeDownload,
            progress: viewModel.runtimeDownloadProgress
        )

        #expect(viewModel.runtimeDownload.isDownloading)
        #expect(card.title == String(localized: "Updating the runtimes list…"))
        #expect(card.action == .cancel)

        viewModel.cancelRuntimeDownload()

        #expect(viewModel.runtimeDownload.isDownloading, "Cancel waits for the listing.")

        service.releaseListing()
        await downloading.value

        guard case let .finished(run) = viewModel.runtimeDownload else {
            Issue.record("Expected a finished queue, got \(viewModel.runtimeDownload)")
            return
        }

        #expect(run.installed == [.iOS])
        #expect(!run.isCancelled)
        #expect(viewModel.phase == .loaded)
    }

    // MARK: - Private Methods

    private func makeViewModel(
        _ service: SimulatorsServiceSpy? = nil,
        downloader: RuntimeDownloaderSpy = RuntimeDownloaderSpy()
    ) -> SimulatorsViewModel {
        SimulatorsViewModel(
            simulators: service ?? SimulatorsServiceSpy(runtimes: [installedRuntime]),
            downloader: downloader,
            versionSource: InertRuntimeVersionSource(),
            analytics: AnalyticsStub()
        )
    }

    private func select(_ platforms: [RuntimePlatform], in viewModel: SimulatorsViewModel) {
        viewModel.requestRuntimeDownload()

        for platform in platforms {
            viewModel.toggleRuntimePlatform(platform)
        }
    }

}
