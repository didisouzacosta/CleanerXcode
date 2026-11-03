//
//  RuntimeDownloaderSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Records every download and answers as configured for its platform. It signals the platform of
/// each download as it starts, so a test can act while one is in progress without sleeping. It never
/// runs `xcodebuild`.
nonisolated final class RuntimeDownloaderSpy: RuntimeDownloading, Sendable {

    // MARK: - Public Properties

    let started = AsyncStream.makeStream(of: RuntimePlatform.self)

    var calls: [Call] {
        state.withLock { $0.calls }
    }

    var wasCancelled: Bool {
        state.withLock { $0.wasCancelled }
    }

    // MARK: - Private Properties

    private let defaultBehavior: Behavior
    private let state: Mutex<State>

    // MARK: - Initializers

    init(behaviors: [RuntimePlatform: Behavior] = [:], default defaultBehavior: Behavior = .succeed) {
        self.defaultBehavior = defaultBehavior
        state = Mutex(State(behaviors: behaviors))
    }

    convenience init(behavior: Behavior) {
        self.init(default: behavior)
    }

    // MARK: - Public Methods

    /// Changes how the next downloads of `platform` answer, for example before "Try again".
    func setBehavior(_ behavior: Behavior, for platform: RuntimePlatform) {
        state.withLock { $0.behaviors[platform] = behavior }
    }

    /// Ends a `.hold` download successfully, now or as soon as it starts.
    func release() {
        let waiter = state.withLock { state in
            state.isReleased = true

            defer { state.waiter = nil }
            return state.waiter
        }

        waiter?.resume()
    }

    func download(_ platform: RuntimePlatform, buildVersion: RuntimeBuildVersion?) async throws {
        let behavior = state.withLock { state in
            state.calls.append(Call(platform: platform, buildVersion: buildVersion))
            return state.behaviors[platform, default: defaultBehavior]
        }

        started.continuation.yield(platform)

        switch behavior {
        case .succeed:
            return

        case let .fail(failure):
            throw failure

        case .holdUntilCancelled:
            do {
                try await Task.sleep(for: .seconds(3_600))
            } catch {
                state.withLock { $0.wasCancelled = true }
                throw error
            }

        case .hold:
            await waitForRelease()
        }
    }

    // MARK: - Private Methods

    private func waitForRelease() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumeNow = state.withLock { state in
                guard !state.isReleased else { return true }

                state.waiter = continuation
                return false
            }

            if resumeNow {
                continuation.resume()
            }
        }
    }

    // MARK: - Nested Types

    enum Behavior: Sendable {
        case succeed
        case fail(CleanupError)
        /// Waits until the task is cancelled, then throws `CancellationError`.
        case holdUntilCancelled
        /// Waits for `release()`, then succeeds; cancelling does not end it.
        case hold
    }

    struct Call: Sendable, Equatable {
        let platform: RuntimePlatform
        let buildVersion: RuntimeBuildVersion?
    }

    private struct State {
        var behaviors: [RuntimePlatform: Behavior]
        var calls: [Call] = []
        var wasCancelled = false
        var isReleased = false
        var waiter: CheckedContinuation<Void, Never>?
    }

}
