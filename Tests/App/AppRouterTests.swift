//
//  AppRouterTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Testing
@testable import CleanerXcode

/// The page that "Settings…" (⌘,) and the panel's gear ask the main window to show (C40).
@MainActor
struct AppRouterTests {

    // MARK: - Public Methods

    @Test
    func showingAPageLeavesItPendingUntilTheWindowTakesIt() {
        let router = AppRouter()

        router.show(.general)

        #expect(router.pendingDestination == .general)
        #expect(router.takePendingDestination() == .general)
        #expect(router.pendingDestination == nil)
    }

    @Test
    func withoutARequestThereIsNothingToTake() {
        let router = AppRouter()

        #expect(router.takePendingDestination() == nil)
    }

    @Test
    func theLastRequestWins() {
        let router = AppRouter()

        router.show(.general)
        router.show(.about)

        #expect(router.takePendingDestination() == .about)
        #expect(router.takePendingDestination() == nil)
    }

}
