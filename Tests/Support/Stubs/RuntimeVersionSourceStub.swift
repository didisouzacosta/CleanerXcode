//
//  RuntimeVersionSourceStub.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Answers the SDK versions and the catalog of the "Download runtimes" sheet (C35). With a snapshot,
/// every call answers at once; without one, each call waits for its own release, in call order, so a
/// test can release the SDK versions before the catalog and act while they load, without sleeping.
/// Each call signals when it starts.
nonisolated final class RuntimeVersionSourceStub: RuntimeVersionProviding, Sendable {

    // MARK: - Public Properties

    let arrivals = AsyncStream.makeStream(of: Call.self)

    /// How many times the SDK versions were asked: one per load.
    var callCount: Int {
        sdkChannel.callCount
    }

    // MARK: - Private Properties

    private let immediate: RuntimeVersionsSnapshot?
    private let sdkChannel = StubChannel<[RuntimePlatform: RuntimeBuildVersion]>()
    private let catalogChannel = StubChannel<[RuntimeCatalogEntry]?>()

    // MARK: - Initializers

    init(_ snapshot: RuntimeVersionsSnapshot? = nil) {
        immediate = snapshot
    }

    // MARK: - Public Methods

    /// Answers the oldest SDK read not answered yet, now or as soon as it starts.
    func releaseSDKs(_ versions: [RuntimePlatform: RuntimeBuildVersion]) {
        sdkChannel.release(versions)
    }

    /// Answers the oldest catalog read not answered yet, now or as soon as it starts.
    func releaseCatalog(_ catalog: [RuntimeCatalogEntry]?) {
        catalogChannel.release(catalog)
    }

    /// Both halves of the oldest load.
    func release(_ snapshot: RuntimeVersionsSnapshot) {
        releaseSDKs(snapshot.sdkVersions)
        releaseCatalog(snapshot.catalog)
    }

    func sdkVersions() async throws -> [RuntimePlatform: RuntimeBuildVersion] {
        guard let immediate else {
            return try await sdkChannel.next { arrivals.continuation.yield(.sdkVersions) }
        }

        _ = sdkChannel.claim()
        arrivals.continuation.yield(.sdkVersions)

        return immediate.sdkVersions
    }

    func catalog() async throws -> [RuntimeCatalogEntry]? {
        guard let immediate else {
            return try await catalogChannel.next { arrivals.continuation.yield(.catalog) }
        }

        arrivals.continuation.yield(.catalog)

        return immediate.catalog
    }

    // MARK: - Nested Types

    enum Call: Sendable, Equatable {
        case sdkVersions
        case catalog
    }

}

/// Hands each call the value released for its position; a cancelled call throws `CancellationError`.
nonisolated private final class StubChannel<Value: Sendable>: Sendable {

    // MARK: - Public Properties

    var callCount: Int {
        state.withLock { $0.arrived }
    }

    // MARK: - Private Properties

    private let state = Mutex(State())

    // MARK: - Public Methods

    /// Counts a call that does not wait.
    func claim() -> Int {
        state.withLock { state in
            state.arrived += 1
            return state.arrived
        }
    }

    func next(onArrival: @Sendable () -> Void) async throws -> Value {
        let index = claim()

        onArrival()

        let answer: Answer = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let ready = state.withLock { state -> Answer? in
                    if state.cancelled.contains(index) {
                        return .cancelled
                    }

                    if let value = state.values.removeValue(forKey: index) {
                        return .value(value)
                    }

                    state.waiters[index] = continuation
                    return nil
                }

                if let ready {
                    continuation.resume(returning: ready)
                }
            }
        } onCancel: {
            let waiter = state.withLock { state in
                state.cancelled.insert(index)
                return state.waiters.removeValue(forKey: index)
            }

            waiter?.resume(returning: .cancelled)
        }

        guard case let .value(value) = answer else { throw CancellationError() }

        return value
    }

    func release(_ value: Value) {
        let waiter = state.withLock { state -> CheckedContinuation<Answer, Never>? in
            state.released += 1

            let index = state.released

            if let waiter = state.waiters.removeValue(forKey: index) {
                return waiter
            }

            if !state.cancelled.contains(index) {
                state.values[index] = value
            }

            return nil
        }

        waiter?.resume(returning: .value(value))
    }

    // MARK: - Nested Types

    private enum Answer: Sendable {
        case value(Value)
        case cancelled
    }

    private struct State {
        var arrived = 0
        var released = 0
        var values: [Int: Value] = [:]
        var waiters: [Int: CheckedContinuation<Answer, Never>] = [:]
        var cancelled: Set<Int> = []
    }

}
