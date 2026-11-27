//
//  SimulatorsViewModelRuntimeVersionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Downloading an earlier runtime version from the "Download runtimes" sheet (C35, R4, R8, AC8, AC9):
/// each platform of the queue gets its chosen version, "Try again" repeats it, and without a choice
/// the download is the one of the C30.
struct SimulatorsViewModelRuntimeVersionTests {

    // MARK: - Public Methods

    @Test
    func confirmingDownloadsEachPlatformWithItsVersionInThePlatformOrder() async throws {
        let downloader = RuntimeDownloaderSpy()
        let viewModel = try await loadedViewModel(downloader: downloader)

        viewModel.requestRuntimeDownload()
        viewModel.toggleRuntimePlatform(.watchOS)
        try viewModel.selectRuntimeVersion(version("26.5"), for: .iOS)
        await viewModel.confirmRuntimeDownload()

        #expect(downloader.calls == [
            RuntimeDownloaderSpy.Call(platform: .iOS, buildVersion: RuntimeBuildVersion("26.5")),
            RuntimeDownloaderSpy.Call(platform: .watchOS, buildVersion: nil),
        ])
        #expect(finishedRun(of: viewModel)?.displayName(of: .iOS) == "iOS 26.5")
    }

    @Test
    func choosingAVersionChecksThePlatform() async throws {
        let viewModel = try await loadedViewModel()

        viewModel.requestRuntimeDownload()
        try viewModel.selectRuntimeVersion(version("26.1"), for: .iOS)

        #expect(viewModel.downloadChoice?.selected == [.iOS])
        #expect(viewModel.downloadChoice?.versions.mapValues(\.rawValue) == [.iOS: "26.1"])
    }

    @Test
    func withoutTheSheetChoosingAVersionDoesNothing() async throws {
        let viewModel = try await loadedViewModel()

        try viewModel.selectRuntimeVersion(version("26.1"), for: .iOS)

        #expect(viewModel.downloadChoice == nil)
    }

    /// AC9: "Try again" downloads the failed platforms with the same versions.
    @Test
    func tryAgainRepeatsTheChosenVersions() async throws {
        let downloader = RuntimeDownloaderSpy(behaviors: [.iOS: .fail(.runtimeVersionUnavailable)])
        let viewModel = try await loadedViewModel(downloader: downloader)

        viewModel.requestRuntimeDownload()
        viewModel.toggleRuntimePlatform(.watchOS)
        try viewModel.selectRuntimeVersion(version("26.5"), for: .iOS)
        await viewModel.confirmRuntimeDownload()

        #expect(finishedRun(of: viewModel)?.failed.map(\.failure) == [.runtimeVersionUnavailable])

        downloader.setBehavior(.succeed, for: .iOS)
        await viewModel.retryFailedRuntimeDownloads()

        #expect(downloader.calls.last == RuntimeDownloaderSpy.Call(
            platform: .iOS,
            buildVersion: RuntimeBuildVersion("26.5")
        ))
        #expect(downloader.calls.count == 3)
        #expect(finishedRun(of: viewModel)?.installed == [.iOS])
    }

    /// Closing the sheet forgets the versions: the next sheet starts from Xcode's version.
    @Test
    func cancellingTheSheetForgetsTheVersions() async throws {
        let viewModel = try await loadedViewModel()

        viewModel.requestRuntimeDownload()
        try viewModel.selectRuntimeVersion(version("26.5"), for: .iOS)
        viewModel.cancelRuntimeDownloadChoice()
        viewModel.requestRuntimeDownload()

        #expect(viewModel.downloadChoice?.versions.isEmpty == true)
        #expect(viewModel.downloadChoice?.selected.isEmpty == true)
    }

    /// A version the sheet no longer shows (for example installed since) is never downloaded: the
    /// platform gets the version that matches Xcode, as the sheet shows.
    @Test
    func aVersionTheSheetDoesNotShowDownloadsXcodesVersion() async throws {
        let downloader = RuntimeDownloaderSpy()
        let viewModel = try await loadedViewModel(downloader: downloader)

        viewModel.requestRuntimeDownload()
        try viewModel.selectRuntimeVersion(version("25.0"), for: .iOS)
        await viewModel.confirmRuntimeDownload()

        #expect(downloader.calls == [RuntimeDownloaderSpy.Call(platform: .iOS, buildVersion: nil)])
    }

    /// Confirming while the versions still load keeps what was chosen from the last ones shown.
    @Test(.timeLimit(.minutes(1)))
    func confirmingWhileTheVersionsReloadKeepsTheChoice() async throws {
        let source = RuntimeVersionSourceStub()
        let downloader = RuntimeDownloaderSpy()
        let viewModel = makeViewModel(downloader: downloader, source: source)
        await viewModel.load()

        var arrivals = source.arrivals.stream.makeAsyncIterator()

        let first = Task { await viewModel.runtimeVersions.load() }
        _ = await arrivals.next()
        _ = await arrivals.next()

        try source.release(snapshot())
        await first.value

        let reloading = Task { await viewModel.runtimeVersions.load() }
        _ = await arrivals.next()
        _ = await arrivals.next()

        viewModel.requestRuntimeDownload()
        try viewModel.selectRuntimeVersion(version("26.5"), for: .iOS)
        await viewModel.confirmRuntimeDownload()

        #expect(viewModel.runtimeVersions.isLoading)
        #expect(downloader.calls == [RuntimeDownloaderSpy.Call(
            platform: .iOS,
            buildVersion: RuntimeBuildVersion("26.5")
        )])

        reloading.cancel()
        await reloading.value
    }

    /// B4: asking for the sheet marks the versions as loading at once, before the sheet's task runs.
    @Test
    func requestingTheSheetMarksTheVersionsAsLoading() async throws {
        let viewModel = try await loadedViewModel()

        #expect(!viewModel.runtimeVersions.isLoading)

        viewModel.requestRuntimeDownload()

        #expect(viewModel.downloadChoice != nil)
        #expect(viewModel.runtimeVersions.isLoading)
    }

    /// When the sheet cannot open (a deletion confirmation is open), nothing is marked as loading.
    @Test
    func aSheetThatCannotOpenMarksNothing() async throws {
        let device = SimulatorDevice(
            udid: "A",
            name: "iPhone 17 Pro",
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-2",
            state: .shutdown,
            isAvailable: true,
            lastUsedAt: nil,
            sizeBytes: 1_000
        )
        let viewModel = try SimulatorsViewModel(
            simulators: SimulatorsServiceSpy(devices: [device]),
            downloader: RuntimeDownloaderSpy(),
            versionSource: RuntimeVersionSourceStub(snapshot()),
            analytics: AnalyticsStub()
        )
        await viewModel.load()

        viewModel.toggle("A")
        viewModel.requestDeleteSelected()
        viewModel.requestRuntimeDownload()

        #expect(viewModel.confirmation != nil)
        #expect(viewModel.downloadChoice == nil)
        #expect(!viewModel.runtimeVersions.isLoading)
    }

    // MARK: - Private Methods

    private func version(_ text: String) throws -> RuntimeBuildVersion {
        try #require(RuntimeBuildVersion(text))
    }

    private func loadedViewModel(downloader: RuntimeDownloaderSpy = RuntimeDownloaderSpy()) async throws
        -> SimulatorsViewModel
    {
        let viewModel = try makeViewModel(downloader: downloader, source: RuntimeVersionSourceStub(snapshot()))

        await viewModel.load()
        await viewModel.runtimeVersions.load()

        return viewModel
    }

    private func makeViewModel(
        downloader: RuntimeDownloaderSpy,
        source: RuntimeVersionSourceStub
    ) -> SimulatorsViewModel {
        SimulatorsViewModel(
            simulators: SimulatorsServiceSpy(runtimes: []),
            downloader: downloader,
            versionSource: source,
            analytics: AnalyticsStub()
        )
    }

    /// Xcode 27.2, with the catalog of the fixture as read on Apple silicon.
    private func snapshot() throws -> RuntimeVersionsSnapshot {
        let catalog = try RuntimeCatalogParser.catalog(
            from: SimulatorRuntimeIndexFixture.data(),
            hostArchitecture: "arm64"
        )
        let version = try #require(RuntimeBuildVersion("27.2"))

        return RuntimeVersionsSnapshot(
            sdkVersions: [.iOS: version, .watchOS: version, .tvOS: version, .visionOS: version],
            catalog: catalog.entries
        )
    }

    private func finishedRun(of viewModel: SimulatorsViewModel) -> RuntimeDownloadRun? {
        guard case let .finished(run) = viewModel.runtimeDownload else { return nil }

        return run
    }

}
