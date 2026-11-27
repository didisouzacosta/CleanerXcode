//
//  SectionSummary.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The summary of a section (Figma page 08): "3 of 5 selected · 4.5 GB" as a count, "4.5 GB
/// selected" as bytes, "measuring…" until every row has a size, "cleaning…" while one of its
/// categories is cleaned, and "cleaned" or "2 failed" after a run. The sidebar shows the short
/// `sidebarText`.
enum SectionSummary: Equatable {

    // MARK: - Cases

    case measuring
    case cleaning
    case cleaned
    case failed(Int)
    case selected(bytes: Int64)
    case nothingSelected
    case count(selected: Int, total: Int, bytes: Int64, isDangerous: Bool)

    // MARK: - Public Properties

    /// Already localized: the count joins up to three phrases.
    var text: String {
        switch self {
        case .measuring:
            return String(localized: "measuring…")

        case .cleaning:
            return String(localized: "cleaning…")

        case .cleaned:
            return String(localized: "cleaned")

        case let .failed(count):
            return String(localized: "\(count) failed")

        case let .selected(bytes):
            return String(localized: "\(Self.format(bytes)) selected")

        case .nothingSelected:
            return String(localized: "nothing selected")

        case let .count(selected, total, bytes, isDangerous):
            var parts = [String(localized: "\(selected) of \(total) selected")]

            if selected > 0 {
                parts.append(Self.format(bytes))
            }

            if isDangerous {
                parts.append(String(localized: "dangerous"))
            }

            return parts.joined(separator: " · ")
        }
    }

    /// On the right of the sidebar row: the selected size, or a dash when nothing is selected.
    var sidebarText: String {
        switch self {
        case .measuring:
            String(localized: "Measuring…")

        case .cleaning:
            String(localized: "Cleaning…")

        case .cleaned, .failed:
            text

        case let .selected(bytes):
            Self.format(bytes)

        case .nothingSelected:
            "—"

        case let .count(selected, _, bytes, _):
            selected > 0 ? Self.format(bytes) : "—"
        }
    }

    // MARK: - Initializers

    init(
        categories: [CleanupCategory],
        selectedIDs: Set<CleanupCategoryID>,
        selectedBytes: Int64,
        rows: [CleanupCategoryID: CategoryRowState],
        phase: CleanerPhase,
        style: Style
    ) {
        let ids = Set(categories.map(\.id))
        let selectedCount = ids.intersection(selectedIDs).count

        if categories.contains(where: { rows[$0.id] == .measuring }) {
            self = .measuring
        } else if case let .cleaning(progress) = phase, let current = progress.currentCategory, ids.contains(current) {
            self = .cleaning
        } else if let report = phase.report, report.outcome != .cancelled, let summary = Self.after(report, in: ids) {
            self = summary
        } else if style == .count {
            self = .count(
                selected: selectedCount,
                total: categories.count,
                bytes: selectedBytes,
                isDangerous: categories.contains { $0.risk == .dangerous }
            )
        } else {
            self = selectedCount > 0 ? .selected(bytes: selectedBytes) : .nothingSelected
        }
    }

    // MARK: - Private Methods

    private static func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    /// Only the sections the run touched; the others keep their usual summary.
    private static func after(_ report: CleanupReport, in ids: Set<CleanupCategoryID>) -> SectionSummary? {
        let failed = report.failedCategoryIDs.count { ids.contains($0) }

        if failed > 0 {
            return .failed(failed)
        }

        return report.results.contains { ids.contains($0.categoryID) } ? .cleaned : nil
    }

    // MARK: - Nested Types

    /// `count` on the overview cards while nothing runs and on the page subtitle; `bytes` on the
    /// cards while something runs or reports.
    enum Style: Hashable {
        case count
        case bytes
    }

}
