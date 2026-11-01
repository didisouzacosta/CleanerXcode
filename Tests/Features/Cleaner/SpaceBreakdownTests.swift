//
//  SpaceBreakdownTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The space bar of the overview (Figma page 08): one segment per section with selected bytes, and
/// a legend with every section.
struct SpaceBreakdownTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))

    // MARK: - Public Methods

    @Test
    func onlySectionsWithSelectedBytesBecomeSegmentsInOrder() {
        let breakdown = SpaceBreakdown(bytesBySection: [.userData: 100, .xcode: 300, .temporary: 0])

        #expect(breakdown.segments.map(\.section) == [.xcode, .userData])
        #expect(breakdown.segments.map(\.bytes) == [300, 100])
        #expect(breakdown.segments.map(\.fraction) == [0.75, 0.25])
        #expect(breakdown.totalBytes == 400)
    }

    @Test
    func theFractionsAddUpToOne() {
        let breakdown = SpaceBreakdown(bytesBySection: [
            .xcode: 31_300,
            .simulators: 4_500,
            .temporary: 7,
            .userData: 1,
        ])
        let sum = breakdown.segments.reduce(0) { $0 + $1.fraction }

        #expect(abs(sum - 1) < 0.000_001)
    }

    @Test
    func nothingSelectedHasNoSegments() {
        let breakdown = SpaceBreakdown(bytesBySection: [:])

        #expect(breakdown.totalBytes == 0)
        #expect(breakdown.segments.isEmpty)
        #expect(breakdown.legend.map(\.bytes) == [0, 0, 0, 0])
    }

    /// Every section, "0 KB" included, with its short title.
    @Test
    func theLegendListsEverySection() {
        let breakdown = SpaceBreakdown(bytesBySection: [.xcode: 300])

        #expect(breakdown.legend.map(\.section) == CleanerSection.allCases)
        #expect(breakdown.legend.map(\.bytes) == [300, 0, 0, 0])
        #expect(breakdown.legend.map(\.section.shortTitle.key) == [
            "Xcode",
            "Simulators",
            "Temporary files",
            "User data",
        ])
    }

    /// Unselected, unmeasured and unavailable categories add nothing.
    @Test
    func usesOnlySelectedAndMeasuredCategories() {
        let groups = CleanerSection.grouping(catalog.categories)
        let rows: [CleanupCategoryID: CategoryRowState] = [
            .removeDerivedData: .measured(300),
            .removeCaches: .measured(50),
            .clearDeviceSupport: .measuring,
            .removeArchives: .measured(100),
            .removeXcodeUserData: .unavailable(.xcodeIsRunning),
        ]
        let breakdown = SpaceBreakdown(
            groups: groups,
            selectedIDs: [.removeDerivedData, .clearDeviceSupport, .removeArchives, .removeXcodeUserData],
            rows: rows
        )

        #expect(breakdown.legend.map(\.bytes) == [300, 0, 0, 100])
        #expect(breakdown.totalBytes == 400)
    }

}
