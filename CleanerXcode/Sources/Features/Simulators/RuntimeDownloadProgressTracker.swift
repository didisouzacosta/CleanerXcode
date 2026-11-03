//
//  RuntimeDownloadProgressTracker.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/11/26.
//

/// Turns the steps of one runtime download into the progress the card shows (C34). A new value is
/// published at most once per `publishInterval`, except when the phase changes, and never twice in
/// a row, so the repeated lines of `xcodebuild` cost nothing on the main actor.
struct RuntimeDownloadProgressTracker {

    // MARK: - Public Properties

    static let publishInterval: Duration = .seconds(1)

    // MARK: - Private Properties

    private var estimator = RuntimeDownloadRateEstimator()
    private var published: RuntimeDownloadProgress?
    private var publishedAt: ContinuousClock.Instant?

    // MARK: - Public Methods

    /// The progress to publish now, or `nil` to keep the last one.
    mutating func receive(_ event: RuntimeDownloadEvent, at time: ContinuousClock.Instant) -> RuntimeDownloadProgress? {
        let candidate = progress(for: event, at: time)

        guard candidate != published else { return nil }

        let isNewPhase = published.map { !$0.phase.isSameKind(as: candidate.phase) } ?? true
        let isDue = publishedAt.map { time - $0 >= Self.publishInterval } ?? true

        guard isNewPhase || isDue else { return nil }

        published = candidate
        publishedAt = time
        return candidate
    }

    // MARK: - Private Methods

    /// Completed also shows as installing: only the exit code tells how the download ended.
    private mutating func progress(
        for event: RuntimeDownloadEvent,
        at time: ContinuousClock.Instant
    ) -> RuntimeDownloadProgress {
        switch event {
        case .preparing:
            return RuntimeDownloadProgress(phase: .preparing, remaining: nil)

        case let .downloading(amount):
            estimator.record(received: amount.receivedBytes, total: amount.totalBytes, at: time)

            return RuntimeDownloadProgress(
                phase: .downloading(fraction: amount.fraction),
                remaining: estimator.remaining(at: time).flatMap(RuntimeDownloadRemaining.init(rounding:))
            )

        case .installing, .completed:
            return RuntimeDownloadProgress(phase: .installing, remaining: nil)
        }
    }

}

private extension RuntimeDownloadProgress.Phase {
    func isSameKind(as other: Self) -> Bool {
        switch (self, other) {
        case (.preparing, .preparing), (.downloading, .downloading), (.installing, .installing): true
        default: false
        }
    }
}
