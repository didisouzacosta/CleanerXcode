//
//  CleanerToolbarTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Testing
@testable import CleanerXcode

/// Refresh (⌘R) measures again only on the cleanup pages and while measuring is allowed; on the
/// Settings pages (C40) the item is hidden and the shortcut does nothing.
struct CleanerToolbarTests {

    // MARK: - Public Methods

    @Test(arguments: [SidebarDestination.general, .about])
    func neverRefreshesFromTheSettingsPages(destination: SidebarDestination) {
        #expect(!CleanerToolbar.isRefreshEnabled(destination: destination, phase: .ready))
        #expect(!CleanerToolbar.isRefreshEnabled(destination: destination, phase: .nothingSelected))
    }

    @Test
    func refreshesFromEveryCleanupPageWhileMeasuringIsAllowed() {
        let cleanupPages = SidebarDestination.allCases.filter(\.showsCleanupControls)

        #expect(!cleanupPages.isEmpty)

        for destination in cleanupPages {
            #expect(CleanerToolbar.isRefreshEnabled(destination: destination, phase: .ready), "\(destination)")
            #expect(
                CleanerToolbar.isRefreshEnabled(destination: destination, phase: .measuring(first: false)),
                "\(destination)"
            )
        }
    }

    /// No measurement while a cleanup is being cancelled.
    @Test
    func neverRefreshesWhileACleanupIsCancelling() {
        #expect(!CleanerToolbar.isRefreshEnabled(destination: .overview, phase: .cancelling(freedBytes: 0)))
    }

}
