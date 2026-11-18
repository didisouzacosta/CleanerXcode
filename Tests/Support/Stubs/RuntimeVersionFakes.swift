//
//  RuntimeVersionFakes.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Answers the SDK versions as configured; never runs `xcodebuild`.
nonisolated final class SimulatorSDKReaderStub: SimulatorSDKReading, Sendable {

    // MARK: - Public Properties

    /// Signals each read as it starts.
    let arrivals = AsyncStream.makeStream(of: Void.self)

    // MARK: - Private Properties

    private let behavior: Behavior

    // MARK: - Initializers

    init(_ behavior: Behavior) {
        self.behavior = behavior
    }

    // MARK: - Public Methods

    func simulatorSDKVersions() async throws -> [RuntimePlatform: RuntimeBuildVersion] {
        arrivals.continuation.yield()

        switch behavior {
        case let .versions(versions):
            return versions

        case let .fail(failure):
            throw failure

        case .holdUntilCancelled:
            try await Task.sleep(for: .seconds(3_600))
            return [:]
        }
    }

    // MARK: - Nested Types

    enum Behavior: Sendable {
        case versions([RuntimePlatform: RuntimeBuildVersion])
        case fail(CleanupError)
        /// Throws `CancellationError` when cancelled, as the process runner does.
        case holdUntilCancelled
    }

}

/// Answers the catalog as configured and counts the reads; never reaches the network.
nonisolated final class RuntimeCatalogFetcherStub: RuntimeCatalogFetching, Sendable {

    // MARK: - Public Properties

    let arrivals = AsyncStream.makeStream(of: Void.self)

    var fetchCount: Int {
        count.withLock { $0 }
    }

    // MARK: - Private Properties

    private let behavior: Behavior
    private let count = Mutex(0)

    // MARK: - Initializers

    init(_ behavior: Behavior) {
        self.behavior = behavior
    }

    // MARK: - Public Methods

    func catalog() async throws -> RuntimeCatalog {
        count.withLock { $0 += 1 }
        arrivals.continuation.yield()

        switch behavior {
        case let .catalog(catalog):
            return catalog

        case let .fail(error):
            throw error

        case .holdUntilCancelled:
            // As `URLSession`, which throws `URLError(.cancelled)` rather than `CancellationError`.
            do {
                try await Task.sleep(for: .seconds(3_600))
            } catch {
                throw URLError(.cancelled)
            }

            throw URLError(.timedOut)
        }
    }

    // MARK: - Nested Types

    enum Behavior: Sendable {
        case catalog(RuntimeCatalog)
        case fail(any Error)
        case holdUntilCancelled
    }

}

/// The catalog cache in memory.
nonisolated final class InMemoryRuntimeCatalogCache: RuntimeCatalogStoring, Sendable {

    // MARK: - Public Properties

    var stored: CachedRuntimeCatalog? {
        state.withLock { $0 }
    }

    // MARK: - Private Properties

    private let state: Mutex<CachedRuntimeCatalog?>

    // MARK: - Initializers

    init(_ cached: CachedRuntimeCatalog? = nil) {
        state = Mutex(cached)
    }

    // MARK: - Public Methods

    func load() -> CachedRuntimeCatalog? {
        state.withLock { $0 }
    }

    func save(_ cached: CachedRuntimeCatalog) {
        state.withLock { $0 = cached }
    }

}
