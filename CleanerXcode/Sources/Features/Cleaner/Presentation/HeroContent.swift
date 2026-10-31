//
//  HeroContent.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// What the hero shows in each phase (plan section 2.4, Figma page 03). The total is always
/// labelled "estimated" (R2), and a report is never shown as a success when anything failed (R6).
struct HeroContent {

    // MARK: - Public Properties

    static let fullDiskAccessURL: URL = {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            preconditionFailure("Invalid System Settings URL.")
        }

        return url
    }()

    let eyebrow: LocalizedStringResource
    let amount: String
    let isFreedAmount: Bool
    /// Already localized: some details join two phrases, each with its own plural.
    let detail: String
    let progress: Double?
    let symbol: Symbol?
    let actions: [Action]

    // MARK: - Initializers

    init(viewModel: CleanerViewModel) {
        self.init(
            phase: viewModel.phase,
            totalBytes: viewModel.totalBytes,
            foundBytes: viewModel.foundBytes,
            measuredCategoryCount: viewModel.measuredCategoryCount,
            categoryCount: viewModel.categories.count
        )
    }

    init(phase: CleanerPhase, totalBytes: Int64, foundBytes: Int64, measuredCategoryCount: Int, categoryCount: Int) {
        let total = Self.format(totalBytes)

        switch phase {
        case let .measuring(first):
            self.init(
                measuringFirst: first,
                total: total,
                measuredCategoryCount: measuredCategoryCount,
                categoryCount: categoryCount
            )

        case .ready, .confirming:
            let isReady = phase == .ready

            self.init(
                eyebrow: "Can be freed",
                amount: total,
                detail: String(localized: "estimated · of \(Self.format(foundBytes)) found"),
                actions: [.clean(totalBytes: totalBytes, isEnabled: isReady)]
            )

        case .nothingSelected:
            self.init(
                eyebrow: "Can be freed",
                amount: total,
                detail: String(localized: "Select at least one category below"),
                actions: [Action(.clean, "Nothing selected", isEnabled: false)]
            )

        case .nothingToClean:
            self.init(
                eyebrow: "All clean",
                amount: total,
                detail: String(localized: "Nothing to clean in the selected categories"),
                actions: [Action(.clean, "Nothing to clean", isEnabled: false)]
            )

        case let .cleaning(progress):
            self.init(cleaning: progress)

        case .cancelling:
            self.init(
                eyebrow: "Cancelling…",
                amount: String(localized: "Cancelling…"),
                detail: String(localized: "Finishing the current item safely"),
                actions: [Action(.cancel, "Cancelling…", style: .destructive, isEnabled: false)]
            )

        case let .finished(report):
            self.init(report: report)

        case let .permissionDenied(report):
            self.init(
                eyebrow: "Permission denied",
                amount: Self.format(report.freedBytes),
                isFreedAmount: true,
                detail: String(localized: "macOS blocked access to some folders"),
                symbol: Symbol(name: "lock.fill", tint: .failure),
                actions: [
                    Action(.openPrivacySettings, "Open System Settings"),
                    Action(.retry, "Try again", style: .secondary),
                ]
            )
        }
    }

    private init(measuringFirst isFirst: Bool, total: String, measuredCategoryCount: Int, categoryCount: Int) {
        let clean = Action.clean(totalBytes: 0, isEnabled: false)

        if isFirst {
            self.init(
                eyebrow: "Calculating the space…",
                amount: String(localized: "Measuring…"),
                detail: String(localized: "\(measuredCategoryCount) of \(categoryCount) categories measured"),
                actions: [clean]
            )
        } else {
            self.init(
                eyebrow: "Measuring again…",
                amount: total,
                detail: String(localized: "estimated"),
                actions: [clean]
            )
        }
    }

    private init(cleaning progress: CleanupProgress) {
        let finished = max(progress.startedCategories - 1, 0)
        let current = progress.currentCategory.map { String(localized: CategoryPresentation($0).title) }

        self.init(
            eyebrow: "Cleaning · \(progress.startedCategories) of \(progress.totalCategories) categories",
            amount: Self.format(progress.freedBytes),
            isFreedAmount: true,
            detail: current.map { String(localized: "Removing \($0)…") } ?? String(localized: "Preparing…"),
            progress: Double(finished) / Double(max(progress.totalCategories, 1)),
            actions: [Action(.cancel, "Cancel", style: .destructive)]
        )
    }

    private init(report: CleanupReport) {
        let freed = Self.format(report.freedBytes)
        let finished = report.finishedCategoryCount
        let failedCategories = report.failedCategoryIDs.count
        let cleaned = String(localized: "\(finished) categories cleaned")

        switch report.outcome {
        case .success:
            let trashed = Self.format(report.trashedBytes)

            self.init(
                eyebrow: "Cleanup finished",
                amount: freed,
                isFreedAmount: true,
                detail: report.trashedBytes > 0
                    ? "\(cleaned) · \(String(localized: "\(trashed) went to the Trash"))"
                    : cleaned,
                symbol: Symbol(name: "checkmark.circle.fill", tint: .success),
                actions: [Action(.dismiss, "OK")]
            )

        case .partialFailure, .failure:
            let isPartial = report.outcome == .partialFailure

            self.init(
                eyebrow: isPartial ? "Finished with failures" : "Could not clean",
                amount: freed,
                isFreedAmount: true,
                detail: String(localized: "\(report.failedResults.count) items could not be removed"),
                symbol: Symbol(name: "exclamationmark.triangle.fill", tint: .attention),
                actions: [
                    Action(.retry, "Try again (\(failedCategories))"),
                    Action(.toggleDetails, "Details", style: .secondary),
                ]
            )

        case .cancelled:
            self.init(
                eyebrow: "Cleanup cancelled",
                amount: freed,
                isFreedAmount: true,
                detail: String(localized: "\(finished) categories finished before cancelling"),
                actions: [Action(.dismiss, "OK")]
            )
        }
    }

    private init(
        eyebrow: LocalizedStringResource,
        amount: String,
        isFreedAmount: Bool = false,
        detail: String,
        progress: Double? = nil,
        symbol: Symbol? = nil,
        actions: [Action]
    ) {
        self.eyebrow = eyebrow
        self.amount = amount
        self.isFreedAmount = isFreedAmount
        self.detail = detail
        self.progress = progress
        self.symbol = symbol
        self.actions = actions
    }

    // MARK: - Private Methods

    private static func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    // MARK: - Nested Types

    struct Action: Identifiable {

        // MARK: - Public Properties

        let kind: Kind
        let title: LocalizedStringResource
        let style: Style
        let isEnabled: Bool

        var id: Kind {
            kind
        }

        // MARK: - Initializers

        init(_ kind: Kind, _ title: LocalizedStringResource, style: Style = .prominent, isEnabled: Bool = true) {
            self.kind = kind
            self.title = title
            self.style = style
            self.isEnabled = isEnabled
        }

        // MARK: - Public Methods

        /// "Clean 38.4 GB", or just "Clean" for a plan that frees no space, like the reset (N6).
        static func clean(totalBytes: Int64, isEnabled: Bool) -> Action {
            let title: LocalizedStringResource = totalBytes > 0
                ? "Clean \(HeroContent.format(totalBytes))"
                : "Clean"

            return Action(.clean, title, isEnabled: isEnabled)
        }

        // MARK: - Nested Types

        enum Kind: Hashable {
            case clean
            case cancel
            case dismiss
            case retry
            case toggleDetails
            case openPrivacySettings
        }

        enum Style: Hashable {
            case prominent
            case destructive
            case secondary
        }

    }

    struct Symbol {

        // MARK: - Public Properties

        let name: String
        let tint: Tint

        // MARK: - Nested Types

        enum Tint {
            case success
            case attention
            case failure
        }

    }

}
