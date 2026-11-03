//
//  RuntimeDownloadPreviewFixtures.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

#if DEBUG
    /// The download states of the card previews, close to the Figma frames of the C30.
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

        // MARK: - Private Methods

        private static func run(
            _ platforms: [RuntimePlatform],
            _ outcomes: [RuntimePlatform: RuntimeDownloadOutcome]
        ) -> RuntimeDownloadRun {
            var run = RuntimeDownloadRun(platforms)

            for platform in platforms {
                if let outcome = outcomes[platform] {
                    run.record(outcome, for: platform)
                }
            }

            return run
        }

    }
#endif
