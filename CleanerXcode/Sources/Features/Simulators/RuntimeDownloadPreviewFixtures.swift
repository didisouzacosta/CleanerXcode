//
//  RuntimeDownloadPreviewFixtures.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

#if DEBUG
    /// The download states of the card previews, close to the Figma frames of the C30, and the
    /// progress of the C34 frames.
    enum RuntimeDownloadPreviewFixtures {

        // MARK: - Public Properties

        static let downloadingOne = RuntimeDownloadState.downloading(RuntimeDownloadRun([.iOS]))

        /// iOS installed, watchOS downloading, visionOS queued.
        static let queue = RuntimeDownloadState.downloading(run([.iOS, .watchOS, .visionOS], [.iOS: .installed]))

        static let oneInstalled = RuntimeDownloadState.finished(run([.iOS], [.iOS: .installed]))

        static let allInstalled = RuntimeDownloadState.finished(
            run([.watchOS, .visionOS], [.watchOS: .installed, .visionOS: .installed])
        )

        static let oneFailed = RuntimeDownloadState.finished(run([.iOS], [.iOS: .failed(.timedOut)]))

        static let partlyFailed = RuntimeDownloadState.finished(
            run([.watchOS, .visionOS], [.watchOS: .installed, .visionOS: .failed(.timedOut)])
        )

        static let cancelled = RuntimeDownloadState.finished(run([.iOS], [.iOS: .notDownloaded]))

        static let cancelledAfterInstalling = RuntimeDownloadState.finished(
            run([.watchOS, .visionOS], [.watchOS: .installed, .visionOS: .notDownloaded])
        )

        /// Installed, while the list is updated before the queue ends (N5).
        static let updatingList = RuntimeDownloadState.downloading(run([.iOS], [.iOS: .installed]))

        static let queueUpdatingList = RuntimeDownloadState.downloading(
            run([.watchOS, .visionOS], [.watchOS: .installed, .visionOS: .installed])
        )

        /// C35: iOS 26.5 chosen, downloading (Figma 92:9562).
        static let downloadingEarlierVersion = RuntimeDownloadState.downloading(
            RuntimeDownloadRun([.iOS], versions: earlierIOSVersion)
        )

        /// C35: iOS 26.5 refused by the selected Xcode (Figma 92:9781).
        static let earlierVersionUnavailable = RuntimeDownloadState.finished(
            run([.iOS], [.iOS: .failed(.runtimeVersionUnavailable)], versions: earlierIOSVersion)
        )

        static let threePercent = RuntimeDownloadProgress(phase: .downloading(fraction: 0.03), remaining: nil)

        static let fortyTwoPercent = RuntimeDownloadProgress(
            phase: .downloading(fraction: 0.42),
            remaining: .minutes(12)
        )

        static let sevenPercent = RuntimeDownloadProgress(
            phase: .downloading(fraction: 0.07),
            remaining: .hoursAndMinutes(totalMinutes: 80)
        )

        static let installing = RuntimeDownloadProgress(phase: .installing, remaining: nil)

        /// The steps the page scenarios report, for the same three frames.
        static let threePercentStep = RuntimeDownloadEvent.downloading(
            RuntimeDownloadAmount(fraction: 0.03, receivedBytes: 112_800_000, totalBytes: 3_760_000_000)
        )

        static let fortyTwoPercentSteps = steps(to: 0.42, secondsLeft: 690)
        static let sevenPercentSteps = steps(to: 0.07, secondsLeft: 4_790)

        // MARK: - Private Properties

        private static var earlierIOSVersion: [RuntimePlatform: RuntimeBuildVersion] {
            RuntimeBuildVersion("26.5").map { [.iOS: $0] } ?? [:]
        }

        // MARK: - Private Methods

        /// The steps of a 3,76 GB runtime reaching `fraction` at a steady rate, so that with
        /// `PreviewClock` (10 s a step) about `secondsLeft` remain.
        private static func steps(to fraction: Double, secondsLeft: Double) -> [RuntimeDownloadEvent] {
            let total = 3_760_000_000.0
            let received = total * fraction
            let rate = (total - received) / secondsLeft

            return (0..<5).map { step in
                let bytes = received - Double(4 - step) * rate * 10

                return .downloading(RuntimeDownloadAmount(
                    fraction: bytes / total,
                    receivedBytes: Int64(bytes),
                    totalBytes: Int64(total)
                ))
            }
        }

        private static func run(
            _ platforms: [RuntimePlatform],
            _ outcomes: [RuntimePlatform: RuntimeDownloadOutcome],
            versions: [RuntimePlatform: RuntimeBuildVersion] = [:]
        ) -> RuntimeDownloadRun {
            var run = RuntimeDownloadRun(platforms, versions: versions)

            for platform in platforms {
                if let outcome = outcomes[platform] {
                    run.record(outcome, for: platform)
                }
            }

            return run
        }

    }

    /// A clock for the previews that moves 10 s each time it is read, so the progress of the page
    /// scenarios shows its time left without waiting.
    final class PreviewClock {

        // MARK: - Private Properties

        private var instant = ContinuousClock.now

        // MARK: - Public Methods

        func tick() -> ContinuousClock.Instant {
            instant += .seconds(10)
            return instant
        }

    }
#endif
