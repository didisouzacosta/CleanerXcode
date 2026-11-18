//
//  RuntimeDownloadRateEstimator.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/11/26.
//

/// Estimates the time left of a runtime download from the bytes received (C34). `xcodebuild` prints
/// the bytes with about 3 significant digits, so the rate is taken over a sliding window, between
/// the instants the bytes changed, and smoothed (EWMA). The times always come in as parameters.
struct RuntimeDownloadRateEstimator {

    // MARK: - Public Properties

    static let window: Duration = .seconds(120)
    static let minimumSamples = 3
    static let warmUp: Duration = .seconds(10)
    /// No change for longer means the download stalled, and the estimate hides.
    static let stallLimit: Duration = .seconds(120)
    static let smoothing = 0.3
    static let longest: Duration = .seconds(48 * 3_600)

    // MARK: - Private Properties

    private var samples: [Sample] = []
    private var sampleCount = 0
    private var startedAt: ContinuousClock.Instant?
    private var total: Int64 = 0
    /// Bytes per second.
    private var rate: Double?

    // MARK: - Private Static Methods

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    // MARK: - Public Methods

    /// Only a change of `received` makes a sample; bytes going back or another total start over.
    mutating func record(received: Int64, total: Int64, at time: ContinuousClock.Instant) {
        guard total > 0 else { return }

        if total != self.total || received < (samples.last?.bytes ?? 0) {
            self = Self()
            self.total = total
        }

        guard received != samples.last?.bytes else { return }

        samples.append(Sample(time: time, bytes: received))
        sampleCount += 1

        if startedAt == nil {
            startedAt = time
        }

        // Keeps the last sample before the window starts, so the window never holds just one.
        while samples.count > 2, samples[1].time <= time - Self.window {
            samples.removeFirst()
        }

        guard let oldest = samples.first, let newest = samples.last, newest.time > oldest.time else { return }

        let windowRate = Double(newest.bytes - oldest.bytes) / Self.seconds(newest.time - oldest.time)

        rate = rate.map { Self.smoothing * windowRate + (1 - Self.smoothing) * $0 } ?? windowRate
    }

    /// Counts down between the byte steps; `nil` until there are enough samples and time, while
    /// stalled, or beyond `longest`.
    func remaining(at now: ContinuousClock.Instant) -> Duration? {
        guard
            sampleCount >= Self.minimumSamples,
            let startedAt,
            now - startedAt >= Self.warmUp,
            let rate,
            rate > 0,
            let newest = samples.last,
            now - newest.time <= Self.stallLimit
        else { return nil }

        let seconds = max(0, Double(total - newest.bytes) / rate - Self.seconds(now - newest.time))

        guard seconds <= Self.seconds(Self.longest) else { return nil }

        return .seconds(seconds)
    }

    // MARK: - Nested Types

    private struct Sample {
        let time: ContinuousClock.Instant
        let bytes: Int64
    }

}
