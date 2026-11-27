//
//  RuntimeDownloadRateEstimatorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The time left of a download, from the bytes over a sliding window, smoothed (C34). The instants
/// are synthetic, so nothing waits.
struct RuntimeDownloadRateEstimatorTests {

    // MARK: - Private Properties

    private let base = ContinuousClock.now
    private let gigabyte: Int64 = 1_000_000_000
    private let megabyte: Int64 = 1_000_000

    // MARK: - Public Methods

    @Test
    func thereIsNoEstimateBeforeThreeSamples() {
        var estimator = RuntimeDownloadRateEstimator()

        estimator.record(received: 0, total: gigabyte, at: at(0))
        estimator.record(received: 100 * megabyte, total: gigabyte, at: at(10))

        #expect(estimator.remaining(at: at(12)) == nil)
    }

    @Test
    func thereIsNoEstimateInTheFirstTenSeconds() {
        var estimator = RuntimeDownloadRateEstimator()

        for second in 0..<10 {
            estimator.record(received: Int64(second) * 10 * megabyte, total: gigabyte, at: at(second))
        }

        #expect(estimator.remaining(at: at(9)) == nil)
        #expect(estimator.remaining(at: at(10)) != nil)
    }

    @Test
    func tenMegabytesASecondLeaveEightySecondsAt200Megabytes() throws {
        var estimator = RuntimeDownloadRateEstimator()

        for second in stride(from: 0, through: 20, by: 2) {
            estimator.record(received: Int64(second) * 10 * megabyte, total: gigabyte, at: at(second))
        }

        let remaining = try #require(estimator.remaining(at: at(20)))

        #expect(abs(seconds(remaining) - 80) < 1)
        #expect(RuntimeDownloadRemaining(rounding: remaining) == .minutes(2))
    }

    @Test
    func countsDownBetweenTheSteps() throws {
        var estimator = RuntimeDownloadRateEstimator()

        for second in stride(from: 0, through: 20, by: 2) {
            estimator.record(received: Int64(second) * 10 * megabyte, total: gigabyte, at: at(second))
        }

        let later = try #require(estimator.remaining(at: at(25)))

        #expect(abs(seconds(later) - 75) < 1)
    }

    /// Bytes printed with 3 significant digits, as `xcodebuild` does, still give a steady estimate.
    @Test
    func quantizedBytesGiveASteadyEstimate() throws {
        var estimator = RuntimeDownloadRateEstimator()

        let total: Int64 = 3_760 * megabyte
        let rate = 3.0 * Double(megabyte)

        for second in 0...600 {
            let received = significant(Double(second) * rate)

            estimator.record(received: received, total: total, at: at(second))

            guard second >= 300 else { continue }

            let actual = (Double(total) - Double(second) * rate) / rate
            let estimate = try #require(estimator.remaining(at: at(second)))

            #expect(abs(seconds(estimate) - actual) / actual < 0.1, "At \(second) s")
        }
    }

    @Test
    func aStalledDownloadHasNoEstimate() {
        var estimator = RuntimeDownloadRateEstimator()

        for second in stride(from: 0, through: 20, by: 2) {
            estimator.record(received: Int64(second) * 10 * megabyte, total: gigabyte, at: at(second))
        }

        estimator.record(received: 200 * megabyte, total: gigabyte, at: at(100))

        #expect(estimator.remaining(at: at(140)) != nil)
        #expect(estimator.remaining(at: at(141)) == nil)
    }

    @Test
    func startsOverWhenTheBytesGoBack() {
        var estimator = RuntimeDownloadRateEstimator()

        for second in stride(from: 0, through: 20, by: 2) {
            estimator.record(received: Int64(second) * 10 * megabyte, total: gigabyte, at: at(second))
        }

        estimator.record(received: 1 * megabyte, total: gigabyte, at: at(22))

        #expect(estimator.remaining(at: at(22)) == nil)
    }

    @Test
    func startsOverWhenTheTotalChanges() {
        var estimator = RuntimeDownloadRateEstimator()

        for second in stride(from: 0, through: 20, by: 2) {
            estimator.record(received: Int64(second) * 10 * megabyte, total: gigabyte, at: at(second))
        }

        estimator.record(received: 220 * megabyte, total: 2 * gigabyte, at: at(22))

        #expect(estimator.remaining(at: at(22)) == nil)
    }

    @Test
    func anEstimateBeyondTwoDaysIsNotShown() {
        var estimator = RuntimeDownloadRateEstimator()

        for second in 0...20 {
            estimator.record(received: Int64(second) * 1_000, total: 1_000 * gigabyte, at: at(second))
        }

        #expect(estimator.remaining(at: at(20)) == nil)
    }

    // MARK: - Private Methods

    private func at(_ second: Int) -> ContinuousClock.Instant {
        base + .seconds(second)
    }

    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// Rounded to 3 significant digits, like "27,3 MB" or "1,23 GB".
    private func significant(_ bytes: Double) -> Int64 {
        guard bytes >= 1 else { return 0 }

        let scale = pow(10, floor(log10(bytes)) - 2)

        return Int64((bytes / scale).rounded() * scale)
    }

}
