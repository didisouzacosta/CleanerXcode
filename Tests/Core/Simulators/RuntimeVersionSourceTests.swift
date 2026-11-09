//
//  RuntimeVersionSourceTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The SDK versions and the catalog the sheet offers (C35, R6, R7, AC5, AC16): the catalog is read
/// only when the cache is stale, a failed read falls back to a cache up to 30 days old, and
/// cancelling never falls back.
struct RuntimeVersionSourceTests {

    // MARK: - Private Properties

    nonisolated private static let refreshCases = [
        RefreshCase(refresh: 60, age: 1_800, reads: false),
        RefreshCase(refresh: 60, age: 3_660, reads: true),
        RefreshCase(refresh: 30 * 86_400, age: 6 * 86_400, reads: false),
        RefreshCase(refresh: 30 * 86_400, age: 8 * 86_400, reads: true),
        RefreshCase(refresh: 86_400, age: 86_399, reads: false),
        RefreshCase(refresh: 86_400, age: 86_400, reads: true),
    ]

    private let now = Date(timeIntervalSince1970: 1_794_000_000)

    // MARK: - Public Methods

    @Test
    func aFreshCacheIsUsedWithoutReadingTheCatalog() async throws {
        let cached = try cachedCatalog(age: 3_600, build: "cached")
        let fetcher = try RuntimeCatalogFetcherStub(.catalog(catalog(build: "fetched")))
        let source = try source(fetcher: fetcher, cache: InMemoryRuntimeCatalogCache(cached))

        let snapshot = try await versions(of: source)

        #expect(fetcher.fetchCount == 0)
        #expect(snapshot.catalog?.map(\.build) == ["cached"])
        #expect(snapshot.sdkVersions.mapValues(\.rawValue) == [.iOS: "27.2"])
        #expect(snapshot.isComplete)
    }

    @Test
    func aStaleCacheReadsTheCatalogAndSavesIt() async throws {
        let cache = try InMemoryRuntimeCatalogCache(cachedCatalog(age: 86_401, build: "cached"))
        let fetched = try catalog(build: "fetched")
        let fetcher = RuntimeCatalogFetcherStub(.catalog(fetched))

        let snapshot = try await versions(of: source(fetcher: fetcher, cache: cache))

        #expect(fetcher.fetchCount == 1)
        #expect(snapshot.catalog?.map(\.build) == ["fetched"])
        #expect(cache.stored == CachedRuntimeCatalog(catalog: fetched, fetchedAt: now))
    }

    @Test
    func withoutACacheTheCatalogIsReadAndSaved() async throws {
        let cache = InMemoryRuntimeCatalogCache()
        let fetched = try catalog(build: "fetched")

        let snapshot = try await versions(of: source(
            fetcher: RuntimeCatalogFetcherStub(.catalog(fetched)),
            cache: cache
        ))

        #expect(snapshot.catalog?.map(\.build) == ["fetched"])
        #expect(cache.stored?.fetchedAt == now)
    }

    @Test(arguments: [10 * 86_400.0, 30 * 86_400.0])
    func aFailedReadFallsBackToACacheUpTo30DaysOld(age: TimeInterval) async throws {
        let cache = try InMemoryRuntimeCatalogCache(cachedCatalog(age: age, build: "cached"))
        let fetcher = RuntimeCatalogFetcherStub(.fail(URLError(.notConnectedToInternet)))

        let snapshot = try await versions(of: source(fetcher: fetcher, cache: cache))

        #expect(fetcher.fetchCount == 1)
        #expect(snapshot.catalog?.map(\.build) == ["cached"])
        #expect(cache.stored?.fetchedAt == now.addingTimeInterval(-age), "A fallback is not saved again.")
    }

    @Test
    func aCacheOlderThan30DaysIsNotUsed() async throws {
        let cache = try InMemoryRuntimeCatalogCache(cachedCatalog(age: 40 * 86_400, build: "cached"))

        let snapshot = try await versions(of: source(
            fetcher: RuntimeCatalogFetcherStub(.fail(RuntimeCatalogError.badResponse)),
            cache: cache
        ))

        #expect(snapshot.catalog == nil)
        #expect(!snapshot.isComplete)
    }

    @Test
    func withoutNetworkNorCacheTheCatalogIsUnavailable() async throws {
        let snapshot = try await versions(of: source(
            fetcher: RuntimeCatalogFetcherStub(.fail(RuntimeCatalogError.malformed)),
            cache: InMemoryRuntimeCatalogCache()
        ))

        #expect(snapshot.catalog == nil)
        #expect(snapshot.sdkVersions.mapValues(\.rawValue) == [.iOS: "27.2"])
    }

    /// Without the SDK versions the catalog still loads, but nothing earlier can be offered.
    @Test
    func aFailedSDKReadGivesNoVersions() async throws {
        let snapshot = try await versions(of: source(
            sdks: SimulatorSDKReaderStub(.fail(.toolUnavailable)),
            fetcher: RuntimeCatalogFetcherStub(.catalog(catalog(build: "fetched"))),
            cache: InMemoryRuntimeCatalogCache()
        ))

        #expect(snapshot.sdkVersions.isEmpty)
        #expect(snapshot.catalog?.map(\.build) == ["fetched"])
        #expect(!snapshot.isComplete)
    }

    /// The catalog's refresh interval is kept between 1 hour and 7 days.
    @Test(arguments: refreshCases)
    func theRefreshIntervalIsClamped(refreshCase: RefreshCase) async throws {
        let cached = try CachedRuntimeCatalog(
            catalog: catalog(build: "cached", refresh: .seconds(refreshCase.refresh)),
            fetchedAt: now.addingTimeInterval(-refreshCase.age)
        )
        let fetcher = try RuntimeCatalogFetcherStub(.catalog(catalog(build: "fetched")))

        _ = try await versions(of: source(fetcher: fetcher, cache: InMemoryRuntimeCatalogCache(cached)))

        #expect(fetcher.fetchCount == (refreshCase.reads ? 1 : 0))
        #expect(RuntimeVersionSource.minimumRefreshInterval == .seconds(3_600))
        #expect(RuntimeVersionSource.maximumRefreshInterval == .seconds(7 * 86_400))
    }

    /// A cache dated in the future (the clock moved back) is stale, but can still be the fallback.
    @Test
    func aCacheFromTheFutureIsReadAgain() async throws {
        let cache = try InMemoryRuntimeCatalogCache(cachedCatalog(age: -3_600, build: "cached"))
        let fetcher = try RuntimeCatalogFetcherStub(.catalog(catalog(build: "fetched")))

        let snapshot = try await versions(of: source(fetcher: fetcher, cache: cache))

        #expect(fetcher.fetchCount == 1)
        #expect(snapshot.catalog?.map(\.build) == ["fetched"])
    }

    /// AC16: cancelling while the catalog is read throws, without falling back to the cache.
    @Test(.timeLimit(.minutes(1)))
    func cancellingWhileReadingTheCatalogPropagates() async throws {
        let cache = try InMemoryRuntimeCatalogCache(cachedCatalog(age: 10 * 86_400, build: "cached"))
        let fetcher = RuntimeCatalogFetcherStub(.holdUntilCancelled)
        let source = try source(fetcher: fetcher, cache: cache)

        var arrivals = fetcher.arrivals.stream.makeAsyncIterator()

        let task = Task { try await source.catalog() }
        _ = await arrivals.next()

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingWhileReadingTheSDKsPropagates() async throws {
        let sdks = SimulatorSDKReaderStub(.holdUntilCancelled)
        let source = RuntimeVersionSource(
            sdks: sdks,
            fetcher: RuntimeCatalogFetcherStub(.holdUntilCancelled),
            cache: InMemoryRuntimeCatalogCache(),
            now: { [now] in now }
        )

        var arrivals = sdks.arrivals.stream.makeAsyncIterator()

        let task = Task { try await source.sdkVersions() }
        _ = await arrivals.next()

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    // MARK: - Private Methods

    private func source(
        sdks: SimulatorSDKReaderStub? = nil,
        fetcher: RuntimeCatalogFetcherStub,
        cache: InMemoryRuntimeCatalogCache
    ) throws -> RuntimeVersionSource {
        let sdkVersion = try #require(RuntimeBuildVersion("27.2"))

        return RuntimeVersionSource(
            sdks: sdks ?? SimulatorSDKReaderStub(.versions([.iOS: sdkVersion])),
            fetcher: fetcher,
            cache: cache,
            now: { [now] in now }
        )
    }

    /// Both halves side by side, as the sheet's model reads them.
    private func versions(of source: RuntimeVersionSource) async throws -> RuntimeVersionsSnapshot {
        async let sdkVersions = source.sdkVersions()
        async let catalog = source.catalog()

        return try await RuntimeVersionsSnapshot(sdkVersions: sdkVersions, catalog: catalog)
    }

    private func catalog(build: String, refresh: Duration = .seconds(86_400)) throws -> RuntimeCatalog {
        let version = try #require(RuntimeBuildVersion("26.5"))

        return RuntimeCatalog(
            entries: [RuntimeCatalogEntry(platform: .iOS, version: version, build: build, sizeBytes: 1)],
            refreshInterval: refresh
        )
    }

    private func cachedCatalog(age: TimeInterval, build: String) throws -> CachedRuntimeCatalog {
        try CachedRuntimeCatalog(catalog: catalog(build: build), fetchedAt: now.addingTimeInterval(-age))
    }

    // MARK: - Nested Types

    /// The catalog's refresh interval, the cache's age, both in seconds, and whether it is read again.
    struct RefreshCase: Sendable {
        let refresh: Double
        let age: TimeInterval
        let reads: Bool
    }

}
