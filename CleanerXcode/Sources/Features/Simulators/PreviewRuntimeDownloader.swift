//
//  PreviewRuntimeDownloader.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

#if DEBUG
    import Foundation

    /// Answers each platform's download as configured, for the previews; it never runs `xcodebuild`.
    nonisolated struct PreviewRuntimeDownloader: RuntimeDownloading {

        // MARK: - Private Properties

        private let outcomes: [RuntimePlatform: Outcome]
        private let defaultOutcome: Outcome

        // MARK: - Initializers

        init(_ outcomes: [RuntimePlatform: Outcome] = [:], default defaultOutcome: Outcome = .succeed) {
            self.outcomes = outcomes
            self.defaultOutcome = defaultOutcome
        }

        // MARK: - Public Methods

        func download(_ platform: RuntimePlatform, buildVersion: RuntimeBuildVersion?) async throws {
            switch outcomes[platform, default: defaultOutcome] {
            case .hold:
                try await Task.sleep(for: .seconds(3_600))

            case .succeed:
                return

            case let .fail(failure):
                throw failure
            }
        }

        // MARK: - Nested Types

        enum Outcome: Sendable {
            /// In progress until cancelled.
            case hold
            case succeed
            case fail(CleanupError)
        }

    }
#endif
