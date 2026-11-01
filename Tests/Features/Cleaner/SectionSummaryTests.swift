//
//  SectionSummaryTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The text next to each section title (Figma page 03): what is selected, what was cleaned, or
/// how many failed.
struct SectionSummaryTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))

    private var xcode: [CleanupCategory] {
        [catalog[.removeDerivedData], catalog[.removeCaches], catalog[.clearDeviceSupport]]
    }

    private var userData: [CleanupCategory] {
        [catalog[.removeArchives], catalog[.removeXcodeUserData]]
    }

    // MARK: - Public Methods

    @Test
    func anExpandedSectionShowsTheSelectedSize() {
        #expect(summary(xcode, selected: [.removeDerivedData], bytes: 700) == .selected(bytes: 700))
        #expect(summary(xcode, selected: []) == .nothingSelected)
    }

    /// "3 of 5 selected · 4.5 GB", and "· dangerous" for a section with dangerous items.
    @Test
    func aCollapsedSectionCountsTheSelectedItems() {
        #expect(
            summary(xcode, selected: [.removeDerivedData, .removeCaches], bytes: 700, isCollapsed: true)
                == .count(selected: 2, total: 3, bytes: 700, isDangerous: false)
        )
        #expect(
            summary(userData, selected: [], isCollapsed: true)
                == .count(selected: 0, total: 2, bytes: 0, isDangerous: true)
        )
    }

    @Test
    func aSectionStillBeingMeasuredSaysSo() {
        let rows: [CleanupCategoryID: CategoryRowState] = [.removeDerivedData: .measuring]

        #expect(summary(xcode, selected: [.removeDerivedData], after: (rows, nil)) == .measuring)
        #expect(summary(xcode, selected: [.removeDerivedData], isCollapsed: true, after: (rows, nil)) == .measuring)
    }

    /// After a run, a section is "cleaned" or tells how many of its categories failed; sections
    /// the run never touched keep their usual summary.
    @Test
    func aReportMarksTheSectionsItTouched() {
        let success = CleanupReport(results: [result(.removeDerivedData, .removed)])
        let failure = CleanupReport(results: [
            result(.removeDerivedData, .failed(.inUse)),
            result(.removeCaches, .failed(.permissionDenied)),
            result(.removeCaches, .failed(.inUse)),
        ])

        #expect(summary(xcode, selected: [.removeDerivedData], after: ([:], success)) == .cleaned)
        #expect(summary(xcode, selected: [.removeDerivedData, .removeCaches], after: ([:], failure)) == .failed(2))
        #expect(summary(userData, selected: [], after: ([:], success)) == .nothingSelected)
    }

    /// A cancelled run keeps the usual summary, as in the approved layout.
    @Test
    func aCancelledRunKeepsTheUsualSummary() {
        let cancelled = CleanupReport(results: [result(.removeDerivedData, .removed)], wasCancelled: true)

        #expect(
            summary(xcode, selected: [.removeDerivedData], bytes: 700, after: ([:], cancelled))
                == .selected(bytes: 700)
        )
    }

    // MARK: - Private Methods

    private func summary(
        _ categories: [CleanupCategory],
        selected: Set<CleanupCategoryID>,
        bytes: Int64 = 0,
        isCollapsed: Bool = false,
        after run: (rows: [CleanupCategoryID: CategoryRowState], report: CleanupReport?) = ([:], nil)
    ) -> SectionSummary {
        SectionSummary(
            categories: categories,
            selectedIDs: selected,
            selectedBytes: bytes,
            rows: run.rows,
            report: run.report,
            isCollapsed: isCollapsed
        )
    }

    private func result(_ id: CleanupCategoryID, _ outcome: CleanupItemResult.Outcome) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: 1, outcome: outcome)
    }

}
