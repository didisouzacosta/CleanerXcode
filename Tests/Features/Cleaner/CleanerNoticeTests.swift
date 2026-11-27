//
//  CleanerNoticeTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Which notices each page shows (Figma page 08): the overview shows them all, and each page only
/// the ones about its own items.
struct CleanerNoticeTests {

    // MARK: - Private Properties

    private let denied = CleanerPhase.permissionDenied(CleanupReport(results: [
        CleanupItemResult(
            categoryID: .removeArchives,
            displayPath: "~/Archives",
            bytes: 1,
            outcome: .failed(.permissionDenied)
        ),
    ]))

    // MARK: - Public Methods

    @Test
    func theOverviewShowsEveryNotice() {
        #expect(notices(.overview) == [.permissionDenied, .xcodeOpen, .simulatorsOpen, .toolsUnavailable, .trashBound])
    }

    @Test
    func eachPageShowsOnlyItsOwnNotices() {
        #expect(notices(.xcode) == [.xcodeOpen])
        #expect(notices(.simulators) == [.simulatorsOpen, .toolsUnavailable])
        #expect(notices(.temporary).isEmpty)
        #expect(notices(.userData) == [.xcodeOpen, .trashBound])
        #expect(notices(.simulatorsAndRuntimes) == [.simulatorsOpen, .toolsUnavailable])
    }

    /// The Settings pages (C40) never show a notice, whatever happens.
    @Test
    func theSettingsPagesNeverShowANotice() {
        #expect(notices(.general).isEmpty)
        #expect(notices(.about).isEmpty)
    }

    /// The Trash notice follows the sections that send selected items there.
    @Test
    func theTrashNoticeFollowsTheTrashBoundCategories() {
        #expect(notices(.xcode, trashBound: [.removeDerivedData]) == [.xcodeOpen, .trashBound])
        #expect(notices(.userData, trashBound: []) == [.xcodeOpen])
        #expect(notices(.overview, trashBound: []).contains(.trashBound) == false)
    }

    @Test
    func noConditionMeansNoNotice() {
        for destination in SidebarDestination.allCases {
            let shown = CleanerNotice.notices(
                for: destination,
                phase: .ready,
                restrictions: CleanupRestrictions(categories: [], isXcodeRunning: false, areSimulatorsActive: false),
                areSimulatorToolsUnavailable: false,
                trashBound: []
            )

            #expect(shown.isEmpty, "\(destination)")
        }
    }

    // MARK: - Private Methods

    private func notices(
        _ destination: SidebarDestination,
        trashBound: Set<CleanupCategoryID> = [.removeArchives]
    ) -> [CleanerNotice] {
        CleanerNotice.notices(
            for: destination,
            phase: denied,
            restrictions: CleanupRestrictions(categories: [], isXcodeRunning: true, areSimulatorsActive: true),
            areSimulatorToolsUnavailable: true,
            trashBound: trashBound
        )
    }

}
