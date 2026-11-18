//
//  OverviewPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import CoreGraphics
import Foundation

/// Texts of the overview page (Figma page 08) that depend on the phase, and the columns of its
/// section grid (C40).
enum OverviewPresentation {

    // MARK: - Public Properties

    nonisolated static let sectionCardMinimumWidth: CGFloat = 280
    nonisolated static let sectionGridSpacing: CGFloat = 12

    // MARK: - Public Methods

    /// The four section cards under the full-width "Simulators and runtimes" one take 1, 2 or 4
    /// equal columns, never 3, so no row is left incomplete (C40).
    nonisolated static func sectionColumnCount(
        availableWidth: CGFloat,
        minimumCardWidth: CGFloat = sectionCardMinimumWidth,
        spacing: CGFloat = sectionGridSpacing
    ) -> Int {
        for columns in [4, 2] {
            let neededWidth = CGFloat(columns) * minimumCardWidth + CGFloat(columns - 1) * spacing

            if availableWidth >= neededWidth {
                return columns
            }
        }

        return 1
    }

    /// "4 categories with selected items" next to "Sections", only while nothing runs or reports.
    static func sectionsCaption(phase: CleanerPhase, selectedCount: Int) -> LocalizedStringResource? {
        switch phase {
        case .ready, .confirming, .nothingSelected, .nothingToClean:
            "\(selectedCount) categories with selected items"

        case .measuring, .cleaning, .cancelling, .finished, .permissionDenied:
            nil
        }
    }

    /// The overview cards count the selected items while nothing runs, as in the layout, and show
    /// the selected size, "cleaning…" or the result while a cleanup runs or reports.
    static func cardStyle(phase: CleanerPhase) -> SectionSummary.Style {
        switch phase {
        case .ready, .confirming, .nothingSelected, .nothingToClean: .count
        case .measuring, .cleaning, .cancelling, .finished, .permissionDenied: .bytes
        }
    }

    /// The failed items close when their report is dismissed or replaced. A first report keeps
    /// them as they were: closed in the app, open in the previews that start with them.
    static func closesFailures(whenReportChangesFrom oldReport: CleanupReport?) -> Bool {
        oldReport != nil
    }

}
