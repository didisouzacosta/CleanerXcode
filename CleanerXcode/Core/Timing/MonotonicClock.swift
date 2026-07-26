import Foundation

protocol MonotonicClock: Sendable {
    func now() -> Duration
    func sleep(for duration: Duration) async throws
}

struct ContinuousMonotonicClock: MonotonicClock, Sendable {

    // MARK: - Private Properties

    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    // MARK: - Initializer

    init() {
        origin = clock.now
    }

    // MARK: - Public Methods

    func now() -> Duration {
        origin.duration(to: clock.now)
    }

    func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}
