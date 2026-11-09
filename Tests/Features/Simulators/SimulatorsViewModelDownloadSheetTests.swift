//
//  SimulatorsViewModelDownloadSheetTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The "Download runtimes" sheet (C30, A1, R14): it opens with nothing selected, never during a
/// download, a deletion or a deletion confirmation, and no deletion is asked while it is open.
struct SimulatorsViewModelDownloadSheetTests {

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
    func startsIdleWithoutASheetOrDownload() {
        let downloader = RuntimeDownloaderSpy()
        let viewModel = makeViewModel(SimulatorsServiceSpy(), downloader: downloader)

        viewModel.cancelRuntimeDownload()

        #expect(viewModel.runtimeDownload == .idle)
        #expect(viewModel.downloadChoice == nil)
        #expect(downloader.calls.isEmpty)
    }

    /// Nothing is pre-selected, so no download of several GB starts by accident (Q9).
    @Test
    func theSheetOpensWithNothingSelectedAndConfirmingNothingDoesNothing() async {
        let downloader = RuntimeDownloaderSpy()
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        viewModel.requestRuntimeDownload()

        #expect(viewModel.downloadChoice == RuntimeDownloadChoice())

        await viewModel.confirmRuntimeDownload()

        #expect(viewModel.downloadChoice == RuntimeDownloadChoice())
        #expect(downloader.calls.isEmpty)
        #expect(viewModel.runtimeDownload == .idle)
    }

    @Test
    func togglingSelectsAndCancellingClosesTheSheet() async {
        let downloader = RuntimeDownloaderSpy()
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        viewModel.toggleRuntimePlatform(.iOS)

        #expect(viewModel.downloadChoice == nil, "Toggling needs an open sheet.")

        viewModel.requestRuntimeDownload()
        viewModel.toggleRuntimePlatform(.tvOS)
        viewModel.toggleRuntimePlatform(.iOS)
        viewModel.toggleRuntimePlatform(.tvOS)

        #expect(viewModel.downloadChoice?.selected == [.iOS])

        viewModel.cancelRuntimeDownloadChoice()

        #expect(viewModel.downloadChoice == nil)
        #expect(downloader.calls.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func theSheetNeverOpensDuringADownload() async {
        let downloader = RuntimeDownloaderSpy(behavior: .holdUntilCancelled)
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await started.next()

        viewModel.requestRuntimeDownload()

        #expect(viewModel.downloadChoice == nil)

        viewModel.cancelRuntimeDownload()
        await downloading.value
    }

    @Test(.timeLimit(.minutes(1)))
    func theSheetNeverOpensDuringADeletion() async {
        let service = SimulatorsServiceSpy(devices: [device], holdsDeletions: true)
        let downloader = RuntimeDownloaderSpy()
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)
        viewModel.cancelRuntimeDownloadChoice()
        viewModel.toggle("A")
        viewModel.requestDeleteSelected()

        var deletionStarted = service.deletionStarted.stream.makeAsyncIterator()

        let deleting = Task { await viewModel.confirm() }
        _ = await deletionStarted.next()

        viewModel.requestRuntimeDownload()

        #expect(viewModel.downloadChoice == nil)

        service.releaseDeletions()
        await deleting.value
    }

    /// "Try again" never runs with the sheet open, as no deletion is asked then either.
    @Test
    func tryAgainNeverRunsWithTheSheetOpen() async {
        let downloader = RuntimeDownloaderSpy(behavior: .fail(.timedOut))
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)
        await viewModel.confirmRuntimeDownload()
        viewModel.requestRuntimeDownload()
        await viewModel.retryFailedRuntimeDownloads()

        #expect(downloader.calls.count == 1)
        #expect(viewModel.downloadChoice == RuntimeDownloadChoice())
        #expect(viewModel.runtimeDownload.isFinished)
    }

    @Test
    func theSheetNeverOpensWithADeletionConfirmationOpen() async {
        let viewModel = makeViewModel(SimulatorsServiceSpy(devices: [device], runtimes: [installedRuntime]))
        await viewModel.load()

        viewModel.requestDeleteRuntime(installedRuntime)
        viewModel.requestRuntimeDownload()

        #expect(viewModel.confirmation != nil)
        #expect(viewModel.downloadChoice == nil)
    }

    @Test
    func noDeletionIsAskedWhileTheSheetIsOpen() async {
        let viewModel = makeViewModel(SimulatorsServiceSpy(devices: [device], runtimes: [installedRuntime]))
        await viewModel.load()

        viewModel.requestRuntimeDownload()
        viewModel.toggle("A")
        viewModel.requestDeleteSelected()
        viewModel.requestDeleteRuntime(installedRuntime)

        #expect(viewModel.confirmation == nil)
        #expect(viewModel.downloadChoice != nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func noRuntimeCanBeRemovedDuringADownload() async {
        let downloader = RuntimeDownloaderSpy(behavior: .holdUntilCancelled)
        let viewModel = makeViewModel(SimulatorsServiceSpy(runtimes: [installedRuntime]), downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await started.next()

        viewModel.requestDeleteRuntime(installedRuntime)

        #expect(viewModel.confirmation == nil)

        viewModel.cancelRuntimeDownload()
        await downloading.value
    }

    @Test(.timeLimit(.minutes(1)))
    func simulatorsCanStillBeDeletedDuringADownload() async {
        let service = SimulatorsServiceSpy(devices: [device], runtimes: [installedRuntime])
        let downloader = RuntimeDownloaderSpy(behavior: .holdUntilCancelled)
        let viewModel = makeViewModel(service, downloader: downloader)
        await viewModel.load()

        select([.iOS], in: viewModel)

        var started = downloader.started.stream.makeAsyncIterator()

        let downloading = Task { await viewModel.confirmRuntimeDownload() }
        _ = await started.next()

        viewModel.toggle("A")
        viewModel.requestDeleteSelected()
        await viewModel.confirm()

        #expect(service.deletedDevices.map { $0.map(\.udid) } == [["A"]])
        #expect(viewModel.runtimeDownload.isDownloading)

        viewModel.cancelRuntimeDownload()
        await downloading.value
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
