//
//  RuntimeDownloadPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation

/// What the runtime download card shows in each state (C30, A1 section 4). The title and caption
/// are already localized, because a queue joins several phrases.
struct RuntimeDownloadPresentation {

    // MARK: - Private Properties

    private static let separator = " · "

    // MARK: - Public Properties

    let systemImage: String
    let tint: Tint
    let title: String
    let caption: String
    /// An indeterminate progress: the output of `xcodebuild -downloadPlatform` is not documented.
    let showsProgress: Bool
    /// Nothing once everything was installed.
    let action: Action?

    // MARK: - Initializers

    init(state: RuntimeDownloadState) {
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
            self = Self.downloading(run)

        case let .finished(run):
            self = Self.finished(run)
        }
    }

    private init(
        systemImage: String,
        tint: Tint,
        title: String,
        caption: String,
        showsProgress: Bool = false,
        action: Action?
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.caption = caption
        self.showsProgress = showsProgress
        self.action = action
    }

    // MARK: - Private Methods

    private static func downloading(_ run: RuntimeDownloadRun) -> Self {
        let platform = (run.current ?? run.platforms.last ?? .iOS).rawValue
        let count = run.platforms.count
        let keepOpen = String(localized: "This can take a while. Keep CleanerXcode open until it finishes.")

        guard count > 1 else {
            return Self(
                systemImage: "arrow.down.circle",
                tint: .accent,
                title: String(localized: "Downloading the \(platform) runtime…"),
                caption: keepOpen,
                showsProgress: true,
                action: .cancel
            )
        }

        var parts = fragments(of: run)

        if !run.queued.isEmpty {
            let queued = run.queued.map(\.rawValue).joined(separator: ", ")

            parts.append(String(localized: "Queued: \(queued)"))
        }

        let joined = parts.joined(separator: separator)

        return Self(
            systemImage: "arrow.down.circle",
            tint: .accent,
            title: String(localized: "Downloading the \(platform) runtime… (\(run.position) of \(count))"),
            caption: parts
                .isEmpty ? keepOpen : String(localized: "\(joined). Keep CleanerXcode open until it finishes."),
            showsProgress: true,
            action: .cancel
        )
    }

    private static func finished(_ run: RuntimeDownloadRun) -> Self {
        let count = run.platforms.count
        let first = (run.platforms.first ?? .iOS).rawValue

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

        let names = run.installed.map(\.rawValue).formatted(.list(type: .and))

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
            let name = platform.rawValue

            return switch run.outcomes[platform] {
            case .installed: String(localized: "\(name) installed")
            case let .failed(failure): "\(name): \(String(localized: failure.summary))"
            case .notDownloaded: String(localized: "\(name) was not downloaded")
            case nil: nil
            }
        }
    }

    // MARK: - Nested Types

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
