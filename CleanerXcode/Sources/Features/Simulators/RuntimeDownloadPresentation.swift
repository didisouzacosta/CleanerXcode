//
//  RuntimeDownloadPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation

/// What the runtime download card shows in each state (C30, A1 section 4), with the progress of the
/// current platform when its output shows it (C34). The title and caption are already localized,
/// because a queue joins several phrases. A platform with a chosen version is named with it, as
/// "iOS 26.5"; otherwise the texts are those of the C30 (C35, R10).
struct RuntimeDownloadPresentation {

    // MARK: - Private Properties

    private static let separator = " · "

    // MARK: - Public Properties

    let systemImage: String
    let tint: Tint
    let title: String
    let caption: String
    /// A bar while downloading with a known percentage; a spinner otherwise during the queue.
    let indicator: Indicator
    /// Nothing once everything was installed.
    let action: Action?

    var showsProgress: Bool {
        indicator != .none
    }

    // MARK: - Initializers

    /// `progress` is the current platform's, read only while downloading.
    init(state: RuntimeDownloadState, progress: RuntimeDownloadProgress? = nil) {
        switch state {
        case .idle:
            self.init(
                systemImage: "arrow.down.circle",
                tint: .secondary,
                title: String(localized: "Download runtimes"),
                caption: String(localized: "Choose the platforms · several GB each"),
                action: .choose
            )

        case let .downloading(run):
            self = Self.downloading(run, progress: progress)

        case let .finished(run):
            self = Self.finished(run)
        }
    }

    private init(
        systemImage: String,
        tint: Tint,
        title: String,
        caption: String,
        indicator: Indicator = .none,
        action: Action?
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.caption = caption
        self.indicator = indicator
        self.action = action
    }

    // MARK: - Private Methods

    private static func downloading(_ run: RuntimeDownloadRun, progress: RuntimeDownloadProgress?) -> Self {
        let platform = run.displayName(of: run.current ?? run.platforms.last ?? .iOS)
        let updating = String(localized: "Updating the runtimes list…")

        // Every platform has an outcome: the last installed runtime is being listed (N5).
        let texts = run.current == nil
            ? Texts(title: updating, indicator: .indeterminate(label: updating))
            : texts(for: progress, platform: platform, position: run.position, count: run.platforms.count)

        return Self(
            systemImage: "arrow.down.circle",
            tint: .accent,
            title: texts.title,
            caption: downloadingCaption(run, remaining: texts.remaining),
            indicator: texts.indicator,
            action: .cancel
        )
    }

    /// Without a recognized line, or while preparing, the texts of the C30.
    private static func texts(
        for progress: RuntimeDownloadProgress?,
        platform: String,
        position: Int,
        count: Int
    ) -> Texts {
        switch progress?.phase {
        case let .downloading(fraction):
            return downloadingTexts(platform, fraction: fraction, remaining: progress?.remaining, position, count)

        case .installing:
            return Texts(
                title: count > 1
                    ? String(localized: "Installing the \(platform) runtime… (\(position) of \(count))")
                    : String(localized: "Installing the \(platform) runtime…"),
                indicator: .indeterminate(label: String(localized: "Installing"))
            )

        case .preparing, nil:
            return Texts(
                title: count > 1
                    ? String(localized: "Downloading the \(platform) runtime… (\(position) of \(count))")
                    : String(localized: "Downloading the \(platform) runtime…"),
                indicator: .indeterminate(label: String(localized: "Downloading"))
            )
        }
    }

    /// The percentage is rounded down, so "100%" never shows before the end.
    private static func downloadingTexts(
        _ platform: String,
        fraction: Double,
        remaining: RuntimeDownloadRemaining?,
        _ position: Int,
        _ count: Int
    ) -> Texts {
        let percent = ((fraction * 100 + 1e-9).rounded(.down) / 100).formatted(.percent.precision(.fractionLength(0)))
        let title = count > 1
            ? String(localized: "Downloading the \(platform) runtime… \(percent) (\(position) of \(count))")
            : String(localized: "Downloading the \(platform) runtime… \(percent)")
        let valueDescription = remaining.map { "\(percent), \($0.text)" } ?? percent

        return Texts(
            title: title,
            indicator: .determinate(fraction: fraction, valueDescription: valueDescription),
            remaining: remaining
        )
    }

    /// The time left first, when known; then, in a queue, what finished and what is queued.
    private static func downloadingCaption(_ run: RuntimeDownloadRun, remaining: RuntimeDownloadRemaining?) -> String {
        var parts = remaining.map { [$0.text] } ?? []

        if run.platforms.count > 1 {
            parts += fragments(of: run)

            if !run.queued.isEmpty {
                let queued = run.queued.map(run.displayName(of:)).joined(separator: ", ")

                parts.append(String(localized: "Queued: \(queued)"))
            }
        }

        guard !parts.isEmpty else {
            return String(localized: "This can take a while. Keep CleanerXcode open until it finishes.")
        }

        let joined = parts.joined(separator: separator)

        return String(localized: "\(joined). Keep CleanerXcode open until it finishes.")
    }

    private static func finished(_ run: RuntimeDownloadRun) -> Self {
        let count = run.platforms.count
        let first = run.displayName(of: run.platforms.first ?? .iOS)

        if run.isCancelled {
            let nothingFinished = run.installed.isEmpty && run.failed.isEmpty

            return Self(
                systemImage: "xmark.circle",
                tint: .secondary,
                title: String(localized: "Download cancelled"),
                caption: nothingFinished
                    ? String(localized: "No runtime was installed.")
                    : fragments(of: run).joined(separator: separator),
                action: .choose
            )
        }

        if let failure = run.failed.first {
            let isSingle = count == 1

            return Self(
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange,
                title: isSingle
                    ? String(localized: "Could not download the \(first) runtime")
                    : String(localized: "\(run.failed.count) of \(count) runtimes were not downloaded"),
                caption: isSingle
                    ? String(localized: failure.failure.summary)
                    : fragments(of: run).joined(separator: separator),
                action: .retry
            )
        }

        let names = run.installed.map(run.displayName(of:)).formatted(.list(type: .and))

        return Self(
            systemImage: "checkmark.circle.fill",
            tint: .green,
            title: count == 1
                ? String(localized: "\(first) runtime installed")
                : String(localized: "\(count) runtimes installed"),
            caption: count == 1
                ? String(localized: "It now shows in the runtimes list.")
                : String(localized: "\(names) now show in the runtimes list."),
            action: nil
        )
    }

    /// One phrase per finished platform, in the queue's order: "watchOS installed",
    /// "visionOS: Timed out" or "visionOS was not downloaded".
    private static func fragments(of run: RuntimeDownloadRun) -> [String] {
        run.finished.compactMap { platform in
            let name = run.displayName(of: platform)

            return switch run.outcomes[platform] {
            case .installed: String(localized: "\(name) installed")
            case let .failed(failure): "\(name): \(String(localized: failure.summary))"
            case .notDownloaded: String(localized: "\(name) was not downloaded")
            case nil: nil
            }
        }
    }

    // MARK: - Nested Types

    enum Indicator: Equatable {
        case none
        case indeterminate(label: String)
        /// `valueDescription` is what VoiceOver reads: the percentage and the time left.
        case determinate(fraction: Double, valueDescription: String)
    }

    /// The title, indicator and time left of a download in progress.
    private struct Texts {
        let title: String
        let indicator: Indicator

        var remaining: RuntimeDownloadRemaining?
    }

    enum Tint {
        case secondary
        case accent
        case green
        case orange
    }

    enum Action {

        // MARK: - Cases

        case choose
        case retry
        case cancel

        // MARK: - Public Properties

        var title: LocalizedStringResource {
            switch self {
            case .choose: "Choose…"
            case .retry: "Try again"
            case .cancel: "Cancel"
            }
        }

    }

}
