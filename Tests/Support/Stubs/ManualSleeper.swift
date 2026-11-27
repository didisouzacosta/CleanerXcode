//
//  ManualSleeper.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

/// A sleep that only ends when the test calls `resume()`, or with `CancellationError` when its task
/// is cancelled. Each request is recorded and signalled, so a test never waits real time. Several
/// sleeps may wait at once (a cancelled one may not have left yet): `resume()` ends all of them.
final class ManualSleeper {

    // MARK: - Public Properties

    let arrivals = AsyncStream.makeStream(of: Duration.self)

    private(set) var requested: [Duration] = []

    // MARK: - Private Properties

    private var pending: [Int: CheckedContinuation<Void, any Error>] = [:]
    private var nextID = 0

    // MARK: - Public Methods

    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()

        nextID += 1

        let id = nextID

        requested.append(duration)
        arrivals.continuation.yield(duration)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
            }
        } onCancel: {
            Task { @MainActor in
                self.cancel(id)
            }
        }
    }

    /// Ends the pending sleeps normally.
    func resume() {
        let continuations = pending.values

        pending = [:]
        continuations.forEach { $0.resume() }
    }

    // MARK: - Private Methods

    private func cancel(_ id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else { return }

        continuation.resume(throwing: CancellationError())
    }

}
