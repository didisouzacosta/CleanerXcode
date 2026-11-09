//
//  RuntimeVersionsModelTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Loading the versions of the "Download runtimes" sheet (C35, R5, AC7, AC16): the sheet never waits
/// for them, the SDK versions show as soon as they arrive while the catalog loads, a newer load
/// supersedes an older one, and cancelling never leaves it loading.
struct RuntimeVersionsModelTests {

    // MARK: - Public Methods

    @Test
    func loadsTheVersions() async throws {
        let snapshot = try snapshot("27.2")
        let model = RuntimeVersionsModel(source: RuntimeVersionSourceStub(snapshot))

        #expect(model.snapshot == nil)
        #expect(!model.isLoading)

        await model.load()

        #expect(model.snapshot == snapshot)
        #expect(!model.isLoading)
    }

    @Test(.timeLimit(.minutes(1)))
    func isLoadingUntilTheVersionsArrive() async throws {
        let source = RuntimeVersionSourceStub()
        let model = RuntimeVersionsModel(source: source)
        let snapshot = try snapshot("27.2")

        var arrivals = source.arrivals.stream.makeAsyncIterator()

        let loading = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()

        #expect(model.isLoading)
        #expect(model.snapshot == nil)

        source.release(snapshot)
        await loading.value

        #expect(!model.isLoading)
        #expect(model.snapshot == snapshot)
    }

    /// The F3 frame: Xcode's version shows its number while the catalog still loads (C35, B2).
    @Test(.timeLimit(.minutes(1)))
    func theSDKVersionsShowBeforeTheCatalog() async throws {
        let source = RuntimeVersionSourceStub()
        let model = RuntimeVersionsModel(source: source)
        let loaded = try snapshot("27.2", catalog: fixtureCatalog())

        var arrivals = source.arrivals.stream.makeAsyncIterator()

        let loading = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()

        source.releaseSDKs(loaded.sdkVersions)
        await waitUntil { model.snapshot != nil }

        let whileLoading = RuntimeVersionOptions.options(for: .iOS, snapshot: model.snapshot, installed: [])

        #expect(model.isLoading)
        #expect(model.snapshot?.catalog == nil)
        #expect(whileLoading.map(\.title) == [String(localized: "\("27.2") (Xcode)")])
        #expect(whileLoading.map(\.sizeBytes) == [nil])

        source.releaseCatalog(loaded.catalog)
        await loading.value

        let options = RuntimeVersionOptions.options(for: .iOS, snapshot: model.snapshot, installed: [])

        #expect(!model.isLoading)
        #expect(model.snapshot == loaded)
        #expect(options.map(\.version?.rawValue) == [nil, "27.1", "26.5", "26.1", "26.0"])
        #expect(options.first?.sizeBytes == 8_321_588_736)
    }

    /// Loading again keeps the last catalog while the new SDK versions arrive.
    @Test(.timeLimit(.minutes(1)))
    func loadingAgainKeepsTheLastCatalogUntilTheNewOneArrives() async throws {
        let source = RuntimeVersionSourceStub()
        let model = RuntimeVersionsModel(source: source)
        let first = try snapshot("27.2", catalog: fixtureCatalog())

        var arrivals = source.arrivals.stream.makeAsyncIterator()

        let loading = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()
        source.release(first)
        await loading.value

        let reloading = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()
        let newerSDKs = try snapshot("27.3").sdkVersions

        source.releaseSDKs(newerSDKs)
        await waitUntil { model.snapshot?.sdkVersions == newerSDKs }

        #expect(model.isLoading)
        #expect(model.snapshot?.catalog == first.catalog)

        source.releaseCatalog([])
        await reloading.value

        #expect(model.snapshot?.catalog == [])
    }

    /// A load that ends after a newer one started is discarded, the SDK phase included, and only the
    /// newest ends the loading.
    @Test(.timeLimit(.minutes(1)))
    func aNewerLoadSupersedesAnOlderOne() async throws {
        let source = RuntimeVersionSourceStub()
        let model = RuntimeVersionsModel(source: source)
        let older = try snapshot("26.5")
        let newer = try snapshot("27.2")

        var arrivals = source.arrivals.stream.makeAsyncIterator()

        let first = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()

        let second = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()

        source.release(older)
        await first.value

        #expect(model.snapshot == nil, "The older load is stale.")
        #expect(model.isLoading)

        source.release(newer)
        await second.value

        #expect(model.snapshot == newer)
        #expect(!model.isLoading)
    }

    /// Closing the sheet cancels the load: the last versions stay, and nothing is left loading.
    @Test(.timeLimit(.minutes(1)))
    func cancellingKeepsTheLastVersionsAndStopsLoading() async throws {
        let source = RuntimeVersionSourceStub()
        let model = RuntimeVersionsModel(source: source)
        let snapshot = try snapshot("27.2")

        var arrivals = source.arrivals.stream.makeAsyncIterator()

        let first = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()

        source.release(snapshot)
        await first.value

        let second = Task { await model.load() }
        // A load asks for the SDK versions and the catalog, in either order.
        _ = await arrivals.next()
        _ = await arrivals.next()

        #expect(model.isLoading)
        #expect(model.snapshot == snapshot, "The last versions stay while loading again.")

        second.cancel()
        await second.value

        #expect(!model.isLoading)
        #expect(model.snapshot == snapshot)
        #expect(source.callCount == 2)
    }

    /// B4: closing the sheet after the SDK versions arrived keeps them (Xcode's number), and the
    /// next opening reads as loading from its first frame, matching the F3 frame.
    @Test(.timeLimit(.minutes(1)))
    func cancellingAfterTheSDKPhaseKeepsItAndTheNextOpeningIsLoading() async throws {
        let source = RuntimeVersionSourceStub()
        let model = RuntimeVersionsModel(source: source)
        let sdkVersions = try snapshot("27.2").sdkVersions

        var arrivals = source.arrivals.stream.makeAsyncIterator()

        let loading = Task { await model.load() }
        _ = await arrivals.next()
        _ = await arrivals.next()

        source.releaseSDKs(sdkVersions)
        await waitUntil { model.snapshot != nil }

        loading.cancel()
        await loading.value

        #expect(!model.isLoading)
        #expect(model.snapshot == RuntimeVersionsSnapshot(sdkVersions: sdkVersions, catalog: nil))

        model.beginLoading()

        let content = RuntimeDownloadSheetContent(
            choice: RuntimeDownloadChoice(),
            runtimes: [],
            versions: model.snapshot,
            isLoadingVersions: model.isLoading
        )

        #expect(model.isLoading)
        #expect(content.versionsNote == .loading)
        #expect(content.rows[0].options.map(\.title) == [String(localized: "\("27.2") (Xcode)")])
        #expect(content.rows[0].options.map(\.sizeBytes) == [nil])
    }

    /// The load that follows `beginLoading()` ends the loading as any other.
    @Test
    func aLoadAfterBeginLoadingEndsTheLoading() async throws {
        let snapshot = try snapshot("27.2")
        let model = RuntimeVersionsModel(source: RuntimeVersionSourceStub(snapshot))

        model.beginLoading()

        #expect(model.isLoading)
        #expect(model.snapshot == nil)

        await model.load()

        #expect(!model.isLoading)
        #expect(model.snapshot == snapshot)
    }

    // MARK: - Private Methods

    private func snapshot(
        _ iOSVersion: String,
        catalog: [RuntimeCatalogEntry]? = []
    ) throws -> RuntimeVersionsSnapshot {
        try RuntimeVersionsSnapshot(sdkVersions: [.iOS: #require(RuntimeBuildVersion(iOSVersion))], catalog: catalog)
    }

    private func fixtureCatalog() throws -> [RuntimeCatalogEntry] {
        try RuntimeCatalogParser.catalog(from: SimulatorRuntimeIndexFixture.data(), hostArchitecture: "arm64").entries
    }

}
