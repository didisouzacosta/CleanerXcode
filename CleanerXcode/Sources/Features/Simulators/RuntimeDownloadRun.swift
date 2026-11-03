//
//  RuntimeDownloadRun.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// A queue of runtime downloads (C30, A1): the chosen platforms, always in the order of
/// `RuntimePlatform.allCases`, downloaded one at a time, and how each one ended.
struct RuntimeDownloadRun: Equatable {

    // MARK: - Public Properties

    let platforms: [RuntimePlatform]

    private(set) var outcomes: [RuntimePlatform: RuntimeDownloadOutcome] = [:]

    /// The first platform without an outcome; `nil` once the queue has ended.
    var current: RuntimePlatform? {
        platforms.first { outcomes[$0] == nil }
    }

    /// 1-based position of the current platform; the count once the queue has ended.
    var position: Int {
        guard let current, let index = platforms.firstIndex(of: current) else { return platforms.count }

        return index + 1
    }

    /// After the current platform.
    var queued: [RuntimePlatform] {
        guard let current, let index = platforms.firstIndex(of: current) else { return [] }

        return Array(platforms[(index + 1)...])
    }

    /// The platforms with an outcome, in the queue's order.
    var finished: [RuntimePlatform] {
        platforms.filter { outcomes[$0] != nil }
    }

    var installed: [RuntimePlatform] {
        platforms.filter { outcomes[$0] == .installed }
    }

    var failed: [Failure] {
        platforms.compactMap { platform in
            guard case let .failed(failure) = outcomes[platform] else { return nil }

            return Failure(platform: platform, failure: failure)
        }
    }

    var notDownloaded: [RuntimePlatform] {
        platforms.filter { outcomes[$0] == .notDownloaded }
    }

    var isCancelled: Bool {
        !notDownloaded.isEmpty
    }

    // MARK: - Initializers

    /// Sorts the selection by `RuntimePlatform.allCases` and drops repeats.
    init(_ selection: some Sequence<RuntimePlatform>) {
        let selected = Set(selection)

        platforms = RuntimePlatform.allCases.filter(selected.contains)
    }

    // MARK: - Public Methods

    /// A platform outside the queue is ignored.
    mutating func record(_ outcome: RuntimeDownloadOutcome, for platform: RuntimePlatform) {
        guard platforms.contains(platform) else { return }

        outcomes[platform] = outcome
    }

    /// Every platform still without an outcome.
    mutating func recordRemaining(_ outcome: RuntimeDownloadOutcome) {
        for platform in platforms where outcomes[platform] == nil {
            outcomes[platform] = outcome
        }
    }

    // MARK: - Nested Types

    struct Failure: Equatable {
        let platform: RuntimePlatform
        let failure: CleanupError
    }

}
