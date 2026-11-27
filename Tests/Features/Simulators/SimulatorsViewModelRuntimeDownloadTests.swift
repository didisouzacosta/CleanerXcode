//
//  SimulatorsViewModelRuntimeDownloadTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Downloading runtimes from the "Simulators and runtimes" page (C30, A1): the sheet picks the
/// platforms, the queue downloads them one at a time in the platforms' order, the lists reload once
/// at the end, and nothing runs together with a deletion.
struct SimulatorsViewModelRuntimeDownloadTests {

    // MARK: - Private Properties

    private let iOS272 = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
    private let iOS271 = "com.apple.CoreSimulator.SimRuntime.iOS-27-1"

    private var device: SimulatorDevice {
        SimulatorDevice(
            udid: "A",
            name: "iPhone 17 Pro",
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
            runtimeIdentifier: iOS271,
            state: .shutdown,
            isAvailable: true,
            lastUsedAt: nil,
            sizeBytes: 1_000
        )
    }

    private var installedRuntime: SimulatorRuntime {
        runtime("R1", iOS271)
    }

    private var downloadedRuntime: SimulatorRuntime {
        runtime("R2", iOS272)
    }

    // MARK: - Public Methods

    @Test
    func confirmingDownloadsOneAtATimeInThePlatformOrderAndListsAfterEachInstall() async {
        let service = SimulatorsServiceSpy(runtimes: [installedRuntime])
        let downloader = RuntimeDownloaderSpy()
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        let listings = service.listingCount

        select([.visionOS, .iOS, .tvOS, .watchOS], in: viewModel)
        service.install(downloadedRuntime)
        await viewModel.confirmRuntimeDownload()

        #expect(downloader.calls.map(\.platform) == [.iOS, .watchOS, .tvOS, .visionOS])
        #expect(downloader.calls.allSatisfy { $0.buildVersion == nil })
        #expect(viewModel.downloadChoice == nil)
        #expect(finishedRun(of: viewModel)?.installed == [.iOS, .watchOS, .tvOS, .visionOS])
        #expect(service.listingCount == listings + 4, "One listing per installed runtime, none more at the end.")
        #expect(viewModel.runtimes.map(\.identifier) == ["R1", "R2"])
        #expect(viewModel.phase == .loaded)
    }

    @Test(.timeLimit(.minutes(1)))
    func theCardFollowsTheQueue() async {
        let downloader = RuntimeDownloaderSpy(behaviors: [.watchOS: .hold])
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS, .watchOS, .visionOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }

        #expect(await started.next() == .iOS)
        #expect(await started.next() == .watchOS)

        guard case let .downloading(run) = viewModel.runtimeDownload else {
            Issue.record("Expected a download in progress, got \(viewModel.runtimeDownload)")
            return
        }

        #expect(run.current == .watchOS)
        #expect(run.position == 2)
        #expect(run.installed == [.iOS])
        #expect(run.queued == [.visionOS])

        downloader.release()
        await downloading.value

        #expect(finishedRun(of: viewModel)?.installed == [.iOS, .watchOS, .visionOS])
    }

    /// Each installed runtime shows at once, with the next one still downloading (P3).
    @Test(.timeLimit(.minutes(1)))
    func anInstalledRuntimeShowsBeforeTheQueueEnds() async {
        let service = SimulatorsServiceSpy(runtimes: [installedRuntime])
        let downloader = RuntimeDownloaderSpy(behaviors: [.watchOS: .hold])
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        let listings = service.listingCount

        select([.iOS, .watchOS, .visionOS], in: viewModel)
        service.install(downloadedRuntime)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }

        #expect(await started.next() == .iOS)
        #expect(await started.next() == .watchOS)
        #expect(viewModel.runtimeDownload.isDownloading)
        #expect(viewModel.runtimes.map(\.identifier) == ["R1", "R2"])
        #expect(service.listingCount == listings + 1)

        downloader.release()
        await downloading.value

        #expect(service.listingCount == listings + 3)
        #expect(viewModel.phase == .loaded)
    }

    /// A cancel that lands while an installed runtime is being listed never turns the listing into
    /// a failure, and no other download starts (A1 §5, P3).
    @Test(.timeLimit(.minutes(1)))
    func cancellingDuringTheListingAfterAnInstallKeepsTheLists() async {
        let service = SimulatorsServiceSpy(runtimes: [installedRuntime])
        let downloader = RuntimeDownloaderSpy(behaviors: [.watchOS: .holdUntilCancelled])
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        select([.iOS, .watchOS], in: viewModel)
        service.install(downloadedRuntime)
        service.holdNextListing()

        var listings = service.listingHeld.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await listings.next()

        viewModel.cancelRuntimeDownload()
        service.releaseListing()
        await downloading.value

        let run = finishedRun(of: viewModel)

        #expect(downloader.calls.map(\.platform) == [.iOS])
        #expect(run?.installed == [.iOS])
        #expect(run?.notDownloaded == [.watchOS])
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.runtimes.map(\.identifier) == ["R1", "R2"])
    }

    /// The platforms are independent: one failure does not stop the others (Q8).
    @Test
    func aFailureInTheMiddleDoesNotStopTheQueue() async {
        let downloader = RuntimeDownloaderSpy(behaviors: [.watchOS: .fail(.timedOut)])
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS, .watchOS, .visionOS], in: viewModel)
        await viewModel.confirmRuntimeDownload()

        let run = finishedRun(of: viewModel)

        #expect(downloader.calls.map(\.platform) == [.iOS, .watchOS, .visionOS])
        #expect(run?.installed == [.iOS, .visionOS])
        #expect(run?.failed == [RuntimeDownloadRun.Failure(platform: .watchOS, failure: .timedOut)])
        #expect(run?.isCancelled == false)
    }

    /// Without the Xcode tools every download would fail the same way, so the queue stops (Q8).
    @Test
    func missingToolsStopTheQueue() async {
        let downloader = RuntimeDownloaderSpy(behavior: .fail(.toolUnavailable))
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS, .tvOS, .visionOS], in: viewModel)
        await viewModel.confirmRuntimeDownload()

        #expect(downloader.calls.map(\.platform) == [.iOS])
        #expect(finishedRun(of: viewModel)?.failed == [
            RuntimeDownloadRun.Failure(platform: .iOS, failure: .toolUnavailable),
            RuntimeDownloadRun.Failure(platform: .tvOS, failure: .toolUnavailable),
            RuntimeDownloadRun.Failure(platform: .visionOS, failure: .toolUnavailable),
        ])
    }

    /// Cancel terminates the current download, starts no other, and the state changes only when
    /// the download has ended.
    @Test(.timeLimit(.minutes(1)))
    func cancellingStopsTheCurrentDownloadAndTheQueue() async {
        let downloader = RuntimeDownloaderSpy(behaviors: [.watchOS: .holdUntilCancelled])
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS, .watchOS, .tvOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await started.next()
        _ = await started.next()

        viewModel.cancelRuntimeDownload()

        #expect(viewModel.runtimeDownload.isDownloading)

        await downloading.value

        let run = finishedRun(of: viewModel)

        #expect(downloader.wasCancelled)
        #expect(downloader.calls.map(\.platform) == [.iOS, .watchOS])
        #expect(run?.installed == [.iOS])
        #expect(run?.notDownloaded == [.watchOS, .tvOS])
        #expect(run?.isCancelled == true)
        #expect(viewModel.phase == .loaded, "The reload after a cancel is not cancelled.")
    }

    @Test
    func tryAgainDownloadsOnlyTheFailedOnes() async {
        let downloader = RuntimeDownloaderSpy(behaviors: [.tvOS: .fail(.timedOut), .visionOS: .fail(.timedOut)])
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS, .tvOS, .visionOS], in: viewModel)
        await viewModel.confirmRuntimeDownload()
        await viewModel.retryFailedRuntimeDownloads()

        #expect(downloader.calls.map(\.platform) == [.iOS, .tvOS, .visionOS, .tvOS, .visionOS])
        #expect(finishedRun(of: viewModel)?.platforms == [.tvOS, .visionOS])
        #expect(viewModel.downloadChoice == nil, "Try again never opens the sheet.")
    }

    /// A runtime removal asked after a failed queue and still open when "Try again" starts is
    /// dropped by `confirm()` without deleting anything, and the download goes on (R6).
    @Test(.timeLimit(.minutes(1)))
    func confirmingARuntimeRemovalDuringTryAgainDeletesNothing() async {
        let service = SimulatorsServiceSpy(runtimes: [installedRuntime])
        let downloader = RuntimeDownloaderSpy(behaviors: [.iOS: .fail(.timedOut)])
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)
        await viewModel.confirmRuntimeDownload()
        viewModel.requestDeleteRuntime(installedRuntime)

        #expect(viewModel.confirmation != nil)

        downloader.setBehavior(.holdUntilCancelled, for: .iOS)

        var started = downloader.started.stream.makeAsyncIterator()

        _ = await started.next()

        let retrying = Task { await viewModel.retryFailedRuntimeDownloads() }
        _ = await started.next()

        await viewModel.confirm()

        #expect(service.calls.isEmpty, "No runtime delete reached simctl.")
        #expect(service.deletedRuntimes.isEmpty)
        #expect(viewModel.confirmation == nil)
        #expect(viewModel.runtimeDownload.isDownloading)

        viewModel.cancelRuntimeDownload()
        await retrying.value
    }

    @Test
    func tryAgainWithoutFailuresDoesNothing() async {
        let downloader = RuntimeDownloaderSpy()
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        await viewModel.retryFailedRuntimeDownloads()

        select([.iOS], in: viewModel)
        await viewModel.confirmRuntimeDownload()
        await viewModel.retryFailedRuntimeDownloads()

        #expect(downloader.calls.map(\.platform) == [.iOS])
    }

    /// A queue that ends while simulators are deleted must not list again: that would end the
    /// deletion's state and bring back what it deletes (B6). The deletion lists at its end.
    @Test(.timeLimit(.minutes(1)))
    func aQueueThatEndsDuringADeletionLeavesTheDeletionAlone() async {
        let service = SimulatorsServiceSpy(devices: [device], holdsDeletions: true)
        let downloader = RuntimeDownloaderSpy(behavior: .hold)
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await started.next()

        viewModel.toggle("A")
        viewModel.requestDeleteSelected()

        var deletionStarted = service.deletionStarted.stream.makeAsyncIterator()

        let deleting = Task { await viewModel.confirm() }
        _ = await deletionStarted.next()

        let listings = service.listingCount

        downloader.release()
        await downloading.value

        #expect(finishedRun(of: viewModel)?.installed == [.iOS])
        #expect(viewModel.phase == .deleting(["A"]))
        #expect(service.listingCount == listings)

        service.releaseDeletions()
        await deleting.value

        #expect(viewModel.phase == .empty)
    }

    @Test(.timeLimit(.minutes(1)))
    func dismissingClearsOnlyAFinishedResult() async {
        let downloader = RuntimeDownloaderSpy(behavior: .holdUntilCancelled)
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        viewModel.dismissRuntimeDownloadResult()

        #expect(viewModel.runtimeDownload == .idle)

        select([.iOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await started.next()

        viewModel.dismissRuntimeDownloadResult()

        #expect(viewModel.runtimeDownload.isDownloading)

        viewModel.cancelRuntimeDownload()
        await downloading.value

        #expect(viewModel.runtimeDownload.isFinished)

        viewModel.dismissRuntimeDownloadResult()

        #expect(viewModel.runtimeDownload == .idle)
    }

    /// The card shows with the lists and on the empty state; otherwise only for a download in
    /// progress or finished, so it can still be cancelled or read.
    @Test
    func theDownloadCardShowsWithTheListsTheEmptyStateOrADownload() async {
        let idle = makeViewModel(SimulatorsServiceSpy())
        let loaded = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]))
        let empty = makeViewModel(SimulatorsServiceSpy())
        let missingTools = makeViewModel(SimulatorsServiceSpy(listFailure: .toolUnavailable))
        let failedDownload = makeViewModel(
            SimulatorsServiceSpy(listFailure: .toolUnavailable),
            downloader: RuntimeDownloaderSpy(behavior: .fail(.toolUnavailable))
        )

        await loaded.load()
        await empty.load()
        await missingTools.load()
        await failedDownload.load()
        select([.iOS], in: failedDownload)
        await failedDownload.confirmRuntimeDownload()

        #expect(!idle.showsRuntimeDownload)
        #expect(loaded.showsRuntimeDownload)
        #expect(empty.showsRuntimeDownload)
        #expect(!missingTools.showsRuntimeDownload)
        #expect(failedDownload.runtimeDownload.isFinished)
        #expect(failedDownload.showsRuntimeDownload)
    }

    @Test
    func theDownloadStatesTellWhetherTheyAreInProgressOrFinished() {
        let run = RuntimeDownloadRun([.iOS])

        #expect(!RuntimeDownloadState.idle.isDownloading)
        #expect(!RuntimeDownloadState.idle.isFinished)
        #expect(RuntimeDownloadState.downloading(run).isDownloading)
        #expect(!RuntimeDownloadState.downloading(run).isFinished)
        #expect(RuntimeDownloadState.finished(run).isFinished)
        #expect(!RuntimeDownloadState.finished(run).isDownloading)
    }

    // MARK: - Private Methods

    private func makeViewModel(
        _ service: SimulatorsServiceSpy,
        downloader: RuntimeDownloaderSpy = RuntimeDownloaderSpy()
    ) -> SimulatorsViewModel {
        SimulatorsViewModel(
            simulators: service,
            downloader: downloader,
            versionSource: InertRuntimeVersionSource(),
            analytics: AnalyticsStub()
        )
    }

    /// Opens the sheet and selects `platforms` in the given order.
    private func select(_ platforms: [RuntimePlatform], in viewModel: SimulatorsViewModel) {
        viewModel.requestRuntimeDownload()

        for platform in platforms {
            viewModel.toggleRuntimePlatform(platform)
        }
    }

    private func finishedRun(of viewModel: SimulatorsViewModel) -> RuntimeDownloadRun? {
        guard case let .finished(run) = viewModel.runtimeDownload else { return nil }

        return run
    }

    private func runtime(_ identifier: String, _ runtimeIdentifier: String) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: identifier,
            runtimeIdentifier: runtimeIdentifier,
            version: "27",
            build: "24A1",
            platformIdentifier: "com.apple.platform.iphonesimulator",
            sizeBytes: 7_000,
            lastUsedAt: nil,
            isDeletable: true,
            state: "Ready",
            kind: "Patchable Cryptex Disk Image"
        )
    }

}
