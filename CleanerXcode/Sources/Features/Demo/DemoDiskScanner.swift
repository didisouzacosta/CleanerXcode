//
//  DemoDiskScanner.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    import Foundation

    /// Measures the demo's disk, one folder after another, so the window fills in as it would.
    nonisolated struct DemoDiskScanner: DiskUsageScanning {

        // MARK: - Public Properties

        static let firstDelay: Duration = .milliseconds(400)
        static let delayBetweenTargets: Duration = .milliseconds(150)

        let state: DemoDiskState
        let delay: @Sendable (CleanupTarget) -> Duration

        // MARK: - Initializers

        init(state: DemoDiskState, delay: (@Sendable (CleanupTarget) -> Duration)? = nil) {
            self.state = state
            self.delay = delay ?? { Self.staggeredDelay(for: $0, in: state) }
        }

        // MARK: - Public Methods

        /// Later entries arrive later; a folder the demo does not know arrives with the first.
        static func staggeredDelay(for target: CleanupTarget, in state: DemoDiskState) -> Duration {
            firstDelay + delayBetweenTargets * (state.order(of: target) ?? 0)
        }

        func allocatedSize(of target: CleanupTarget) async throws -> Int64 {
            try await Task.sleep(for: delay(target))

            return state.size(of: target)
        }

    }
#endif
