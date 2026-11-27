//
//  SectionSummaryTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The summary of each section (Figma page 08): what is selected, what is being cleaned, what was
/// cleaned, or how many failed, as a count, as bytes or as the short sidebar text.
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

    /// "4.5 GB selected" while something runs, or "nothing selected".
    @Test
    func theBytesStyleShowsTheSelectedSize() {
        #expect(summary(xcode, selected: [.removeDerivedData], bytes: 700) == .selected(bytes: 700))
        #expect(summary(xcode, selected: []) == .nothingSelected)
    }

    /// "3 of 5 selected · 4.5 GB", and "· dangerous" for a section with dangerous items.
    @Test
    func theCountStyleCountsTheSelectedItems() {
        #expect(
            summary(xcode, selected: [.removeDerivedData, .removeCaches], bytes: 700, style: .count)
                == .count(selected: 2, total: 3, bytes: 700, isDangerous: false)
        )
        #expect(
            summary(userData, selected: [], style: .count)
                == .count(selected: 0, total: 2, bytes: 0, isDangerous: true)
        )
    }

    @Test
    func aSectionStillBeingMeasuredSaysSo() {
        let rows: [CleanupCategoryID: CategoryRowState] = [.removeDerivedData: .measuring]

        #expect(summary(xcode, selected: [.removeDerivedData], rows: rows) == .measuring)
        #expect(summary(xcode, selected: [.removeDerivedData], style: .count, rows: rows) == .measuring)
    }

    /// Only the section of the category being cleaned says "cleaning…".
    @Test
    func theSectionBeingCleanedSaysSo() {
        let progress = CleanupProgress(totalCategories: 3, startedCategories: 1, currentCategory: .removeCaches)

        #expect(summary(xcode, selected: [.removeCaches], phase: .cleaning(progress)) == .cleaning)
        #expect(summary(xcode, selected: [.removeCaches], style: .count, phase: .cleaning(progress)) == .cleaning)
        #expect(summary(userData, selected: [], phase: .cleaning(progress)) == .nothingSelected)
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

        #expect(summary(xcode, selected: [.removeDerivedData], phase: .finished(success)) == .cleaned)
        #expect(summary(xcode, selected: [.removeDerivedData, .removeCaches], phase: .finished(failure)) == .failed(2))
        #expect(summary(xcode, selected: [.removeDerivedData], phase: .permissionDenied(failure)) == .failed(2))
        #expect(summary(userData, selected: [], phase: .finished(success)) == .nothingSelected)
    }

    /// A cancelled run keeps the usual summary, as in the approved layout.
    @Test
    func aCancelledRunKeepsTheUsualSummary() {
        let cancelled = CleanupReport(results: [result(.removeDerivedData, .removed)], wasCancelled: true)

        #expect(
            summary(xcode, selected: [.removeDerivedData], bytes: 700, phase: .finished(cancelled))
                == .selected(bytes: 700)
        )
    }

    @Test
    func theCleaningTextIsLowercase() {
        #expect(SectionSummary.cleaning.text == String(localized: "cleaning…"))
    }

    /// The short text on the right of each sidebar row: "Measuring…", "Cleaning…", "cleaned",
    /// "1 failed", the selected size, or a dash.
    @Test
    func theSidebarTextIsShort() {
        let size = Int64(700).formatted(.byteCount(style: .file))

        #expect(SectionSummary.measuring.sidebarText == String(localized: "Measuring…"))
        #expect(SectionSummary.cleaning.sidebarText == String(localized: "Cleaning…"))
        #expect(SectionSummary.cleaned.sidebarText == String(localized: "cleaned"))
        #expect(SectionSummary.failed(1).sidebarText == String(localized: "\(1) failed"))
        #expect(SectionSummary.selected(bytes: 700).sidebarText == size)
        #expect(SectionSummary.nothingSelected.sidebarText == "—")
        #expect(SectionSummary.count(selected: 2, total: 5, bytes: 700, isDangerous: true).sidebarText == size)
        #expect(SectionSummary.count(selected: 0, total: 5, bytes: 0, isDangerous: false).sidebarText == "—")
    }

    // MARK: - Private Methods

    private func summary(
        _ categories: [CleanupCategory],
        selected: Set<CleanupCategoryID>,
        bytes: Int64 = 0,
        style: SectionSummary.Style = .bytes,
        rows: [CleanupCategoryID: CategoryRowState] = [:],
        phase: CleanerPhase = .ready
    ) -> SectionSummary {
        SectionSummary(
            categories: categories,
            selectedIDs: selected,
            selectedBytes: bytes,
            rows: rows,
            phase: phase,
            style: style
        )
    }

    private func result(_ id: CleanupCategoryID, _ outcome: CleanupItemResult.Outcome) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: 1, outcome: outcome)
    }

}
