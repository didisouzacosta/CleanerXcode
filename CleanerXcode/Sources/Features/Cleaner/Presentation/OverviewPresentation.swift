//
//  OverviewPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Texts of the overview page (Figma page 08) that depend on the phase.
enum OverviewPresentation {

    // MARK: - Public Methods

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

}
