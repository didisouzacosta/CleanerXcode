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
    /// A run that freed nothing shows its "0 KB" in grey (Figma 9:3490, 17:10078).
    let isAmountDimmed: Bool
    /// Already localized: some details join two phrases, each with its own plural.
    let detail: String
    let progress: Double?
    let symbol: Symbol?
    let actions: [Action]
    /// What the overview's summary card shows under the total (Figma page 08).
    let indicator: Indicator

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
                actions: [.clean(totalBytes: totalBytes, isEnabled: isReady)],
                indicator: .breakdown
            )

        case .nothingSelected:
            self.init(
                eyebrow: "Can be freed",
                amount: total,
                detail: String(localized: "Select at least one category"),
                actions: [Action(.clean, "Nothing selected", isEnabled: false)],
                indicator: .breakdown
            )

        case .nothingToClean:
            self.init(
                eyebrow: "All clean",
                amount: total,
                detail: String(localized: "Nothing to clean in the selected categories"),
                actions: [Action(.clean, "Nothing to clean", isEnabled: false)],
                indicator: .breakdown
            )

        case let .cleaning(progress):
            self.init(cleaning: progress)

        case let .cancelling(freedBytes):
            self.init(
                eyebrow: "Cancelling…",
                amount: Self.format(freedBytes),
                isFreedAmount: freedBytes > 0,
                detail: String(localized: "Finishing the current item safely"),
                actions: [Action(.cancel, "Cancelling…", style: .destructive, isEnabled: false)]
            )

        case let .finished(report):
            self.init(report: report)

        case let .permissionDenied(report):
            self.init(permissionDenied: report)
        }
    }

    private init(permissionDenied report: CleanupReport) {
        self.init(
            eyebrow: "Permission denied",
            amount: Self.format(report.freedBytes),
            isFreedAmount: report.freedBytes > 0,
            isAmountDimmed: report.freedBytes == 0,
            detail: String(
                localized: "macOS blocked access to \(max(report.permissionDeniedResults.count, 1)) items"
            ),
            symbol: Symbol(name: "lock.fill", tint: .failure),
            actions: [
                Action(.openPrivacySettings, "Open System Settings"),
                Action(.retry, "Try again", style: .secondary),
            ]
        )
    }

    private init(measuringFirst isFirst: Bool, total: String, measuredCategoryCount: Int, categoryCount: Int) {
        let clean = Action.clean(totalBytes: 0, isEnabled: false)

        if isFirst {
            self.init(
                eyebrow: "Calculating the space…",
                amount: String(localized: "Measuring…"),
                detail: String(localized: "\(measuredCategoryCount) of \(categoryCount) categories measured"),
                actions: [clean],
                indicator: .progress(Double(measuredCategoryCount) / Double(max(categoryCount, 1)))
            )
        } else {
            self.init(
                eyebrow: "Measuring again…",
                amount: total,
                detail: String(localized: "estimated"),
                actions: [clean],
                indicator: .breakdown
            )
        }
    }

    private init(cleaning progress: CleanupProgress) {
        let finished = max(progress.startedCategories - 1, 0)
        let current = progress.currentCategory.map { String(localized: CategoryPresentation($0).title) }
        let fraction = Double(finished) / Double(max(progress.totalCategories, 1))

        self.init(
            eyebrow: "Cleaning · \(progress.startedCategories) of \(progress.totalCategories) categories",
            amount: Self.format(progress.freedBytes),
            isFreedAmount: progress.freedBytes > 0,
            detail: current.map { String(localized: "Removing \($0)…") } ?? String(localized: "Preparing…"),
            progress: fraction,
            actions: [Action(.cancel, "Cancel", style: .destructive)],
            indicator: .progress(fraction)
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
                isFreedAmount: report.freedBytes > 0,
                isAmountDimmed: report.freedBytes == 0,
                detail: report.trashedBytes > 0
                    ? "\(cleaned) · \(String(localized: "\(trashed) went to the Trash"))"
                    : cleaned,
                symbol: Symbol(name: "checkmark.circle.fill", tint: .success),
                actions: [Action(.dismiss, "OK", style: .secondary)]
            )

        case .partialFailure:
            let items = String(localized: "\(report.failedResults.count) items could not be removed")
            let categories = String(localized: "in \(failedCategories) categories")

            self.init(
                eyebrow: "Finished with failures",
                amount: freed,
                isFreedAmount: report.freedBytes > 0,
                isAmountDimmed: report.freedBytes == 0,
                detail: "\(items) \(categories)",
                symbol: Symbol(name: "exclamationmark.triangle.fill", tint: .attention),
                actions: [
                    Action(.retry, "Try again (\(report.failedResults.count))"),
                    Action(.toggleDetails, "See details", style: .secondary),
                ]
            )

        case .failure:
            let categories = String(localized: "\(failedCategories) categories failed")

            self.init(
                eyebrow: "Could not clean",
                amount: freed,
                isFreedAmount: report.freedBytes > 0,
                isAmountDimmed: report.freedBytes == 0,
                detail: "\(String(localized: "No item was removed")) · \(categories)",
                symbol: Symbol(name: "xmark.circle.fill", tint: .failure),
                actions: [
                    Action(.retry, "Try again"),
                    Action(.toggleDetails, "See details", style: .secondary),
                ]
            )

        case .cancelled:
            self.init(
                eyebrow: "Cleanup cancelled",
                amount: freed,
                isFreedAmount: report.freedBytes > 0,
                isAmountDimmed: report.freedBytes == 0,
                detail: String(localized: "\(finished) categories finished before cancelling"),
                actions: [Action(.dismiss, "OK", style: .secondary)]
            )
        }
    }

    private init(
        eyebrow: LocalizedStringResource,
        amount: String,
        isFreedAmount: Bool = false,
        isAmountDimmed: Bool = false,
        detail: String,
        progress: Double? = nil,
        symbol: Symbol? = nil,
        actions: [Action],
        indicator: Indicator = .none
    ) {
        self.eyebrow = eyebrow
        self.amount = amount
        self.isFreedAmount = isFreedAmount
        self.isAmountDimmed = isAmountDimmed
        self.detail = detail
        self.progress = progress
        self.symbol = symbol
        self.actions = actions
        self.indicator = indicator
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

    enum Indicator: Equatable {
        case none
        /// The share of categories measured, or of the cleanup done.
        case progress(Double)
        /// The space bar with the legend of each section.
        case breakdown
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
