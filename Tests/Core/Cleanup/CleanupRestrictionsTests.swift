//
//  CleanupRestrictionsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CleanupRestrictionsTests {

    // MARK: - Private Properties

    private let categories = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/tester", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/ab/cd/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp", directoryHint: .isDirectory)
    )).categories

    // MARK: - Public Methods

    @Test
    func nothingIsRestrictedWhenNeitherXcodeNorSimulatorsAreRunning() {
        let restrictions = CleanupRestrictions(
            categories: categories,
            isXcodeRunning: false,
            areSimulatorsActive: false
        )

        #expect(restrictions.blockedCategoryIDs.isEmpty)
        #expect(restrictions.warnings.isEmpty)
    }

    @Test
    func withXcodeOpenTheXcodeSettingsAreBlockedAndDerivedDataWarns() {
        let restrictions = CleanupRestrictions(categories: categories, isXcodeRunning: true, areSimulatorsActive: false)

        #expect(restrictions.blockedCategoryIDs == [.resetXcodePreferences, .removeXcodeUserData])
        #expect(restrictions.warnings == [.removeDerivedData: .xcodeIsRunning])
        #expect(restrictions.isBlocked(.resetXcodePreferences))
        #expect(!restrictions.isBlocked(.removeDerivedData))
    }

    @Test
    func withSimulatorsActiveEverySimulatorCategoryWarnsThatTheyWillClose() {
        let restrictions = CleanupRestrictions(categories: categories, isXcodeRunning: false, areSimulatorsActive: true)

        #expect(restrictions.blockedCategoryIDs.isEmpty)
        #expect(restrictions.warnings == [
            .clearSimulatorData: .simulatorsWillClose,
            .removeOldSimulators: .simulatorsWillClose,
            .clearAuxiliaryDeviceSets: .simulatorsWillClose,
            .clearSimulatorCaches: .simulatorsWillClose,
        ])
    }

    @Test
    func bothAtOnceKeepEachRuleSeparate() {
        let restrictions = CleanupRestrictions(categories: categories, isXcodeRunning: true, areSimulatorsActive: true)

        #expect(restrictions.blockedCategoryIDs == [.resetXcodePreferences, .removeXcodeUserData])
        #expect(restrictions.warnings[.removeDerivedData] == .xcodeIsRunning)
        #expect(restrictions.warnings[.clearSimulatorCaches] == .simulatorsWillClose)
        #expect(restrictions.warnings.count == 5)
    }

}
