//
//  SectionSummary.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The text next to a section title (Figma page 03): "31.3 GB selected" when expanded, "3 of 5
/// selected · 4.5 GB" when collapsed, "measuring…" until every row has a size, and "cleaned" or
/// "2 failed" after a run.
enum SectionSummary: Equatable {

    // MARK: - Cases

    case measuring
    case cleaned
    case failed(Int)
    case selected(bytes: Int64)
    case nothingSelected
    case count(selected: Int, total: Int, bytes: Int64, isDangerous: Bool)

    // MARK: - Public Properties

    /// Already localized: the collapsed summary joins up to three phrases.
    var text: String {
        switch self {
        case .measuring:
            return String(localized: "measuring…")

        case .cleaned:
            return String(localized: "cleaned")

        case let .failed(count):
            return String(localized: "\(count) failed")

        case let .selected(bytes):
            return String(localized: "\(bytes.formatted(.byteCount(style: .file))) selected")

        case .nothingSelected:
            return String(localized: "nothing selected")

        case let .count(selected, total, bytes, isDangerous):
            var parts = [String(localized: "\(selected) of \(total) selected")]

            if selected > 0 {
                parts.append(bytes.formatted(.byteCount(style: .file)))
            }

            if isDangerous {
                parts.append(String(localized: "dangerous"))
            }

            return parts.joined(separator: " · ")
        }
    }

    // MARK: - Initializers

    init(
        categories: [CleanupCategory],
        selectedIDs: Set<CleanupCategoryID>,
        selectedBytes: Int64,
        rows: [CleanupCategoryID: CategoryRowState],
        report: CleanupReport?,
        isCollapsed: Bool
    ) {
        let ids = Set(categories.map(\.id))
        let selectedCount = ids.intersection(selectedIDs).count

        if categories.contains(where: { rows[$0.id] == .measuring }) {
            self = .measuring
        } else if let report, report.outcome != .cancelled, let summary = Self.after(report, in: ids) {
            self = summary
        } else if isCollapsed {
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

    /// Only the sections the run touched; the others keep their usual summary.
    private static func after(_ report: CleanupReport, in ids: Set<CleanupCategoryID>) -> SectionSummary? {
        let failed = report.failedCategoryIDs.count { ids.contains($0) }

        if failed > 0 {
            return .failed(failed)
        }

        return report.results.contains { ids.contains($0.categoryID) } ? .cleaned : nil
    }

}
