//
//  RuntimeVersionProviding.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// The versions the "Download runtimes" sheet offers (C35), in two halves the sheet reads side by
/// side: the SDK versions, quick, shown as soon as they arrive, and the catalog. Only cancellation
/// throws (`CancellationError`); anything else that fails is missing, so the sheet falls back to the
/// version that matches Xcode (R6).
nonisolated protocol RuntimeVersionProviding: Sendable {
    /// Empty when they cannot be read.
    func sdkVersions() async throws -> [RuntimePlatform: RuntimeBuildVersion]
    /// `nil` when the catalog is unavailable: no network nor usable cache, or unreadable.
    func catalog() async throws -> [RuntimeCatalogEntry]?
}

/// Reads the SDK versions and the catalog (R7). The catalog comes from the cache while it is fresh
/// (its refresh interval, kept between 1 hour and 7 days); otherwise it is read and saved; a failed
/// read falls back to a cache up to 30 days old. Cancelling, as closing the sheet does, ends the read
/// and never falls back.
nonisolated struct RuntimeVersionSource: RuntimeVersionProviding {

    // MARK: - Public Properties

    static let minimumRefreshInterval: Duration = .seconds(3_600)
    static let maximumRefreshInterval: Duration = .seconds(7 * 86_400)
    /// The oldest cache used when the catalog cannot be read.
    static let fallbackAge: TimeInterval = 30 * 86_400

    // MARK: - Private Properties

    private let sdks: any SimulatorSDKReading
    private let fetcher: any RuntimeCatalogFetching
    private let cache: any RuntimeCatalogStoring
    private let now: @Sendable () -> Date

    // MARK: - Initializers

    init(
        sdks: any SimulatorSDKReading,
        fetcher: any RuntimeCatalogFetching,
        cache: any RuntimeCatalogStoring,
        now: @escaping @Sendable () -> Date
    ) {
        self.sdks = sdks
        self.fetcher = fetcher
        self.cache = cache
        self.now = now
    }

    // MARK: - Private Static Methods

    /// Fresh from when it was read until its clamped refresh interval has passed; a date in the
    /// future (the clock moved back) is stale.
    private static func isFresh(_ cached: CachedRuntimeCatalog, at date: Date) -> Bool {
        let interval = min(max(cached.catalog.refreshInterval, minimumRefreshInterval), maximumRefreshInterval)
        let age = date.timeIntervalSince(cached.fetchedAt)

        return age >= 0 && age < seconds(of: interval)
    }

    private static func seconds(of duration: Duration) -> TimeInterval {
        let components = duration.components

        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }

    /// `URLSession` ends a cancelled request with `URLError(.cancelled)`, not `CancellationError`.
    private static func rethrowIfCancelled(_ error: any Error) throws {
        if error is CancellationError || Task.isCancelled {
            throw CancellationError()
        }
    }

    // MARK: - Public Methods

    func sdkVersions() async throws -> [RuntimePlatform: RuntimeBuildVersion] {
        do {
            let versions = try await sdks.simulatorSDKVersions()

            try Task.checkCancellation()

            return versions
        } catch {
            try Self.rethrowIfCancelled(error)

            return [:]
        }
    }

    func catalog() async throws -> [RuntimeCatalogEntry]? {
        let catalog = try await readCatalog()

        try Task.checkCancellation()

        return catalog?.entries
    }

    // MARK: - Private Methods

    private func readCatalog() async throws -> RuntimeCatalog? {
        let cached = await cache.load()
        let date = now()

        if let cached, Self.isFresh(cached, at: date) {
            return cached.catalog
        }

        do {
            let catalog = try await fetcher.catalog()

            await cache.save(CachedRuntimeCatalog(catalog: catalog, fetchedAt: now()))

            return catalog
        } catch {
            try Self.rethrowIfCancelled(error)

            guard let cached, date.timeIntervalSince(cached.fetchedAt) <= Self.fallbackAge else { return nil }

            return cached.catalog
        }
    }

}
