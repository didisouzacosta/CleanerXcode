//
//  LiveMeasurementPolicyTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// When a category is measured again after its folders change (C40 · tempo real, R2–R4): 5 s after
/// the changes stop, at most once a minute, and never right after a measurement that saw them.
struct LiveMeasurementPolicyTests {

    // MARK: - Private Properties

    private let policy = LiveMeasurementPolicy()
    private let start = Date(timeIntervalSince1970: 100_000)

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))

    // MARK: - Public Methods

    @Test
    func theValuesFollowTheOwnersChoice() {
        #expect(policy.quietPeriod == .seconds(5))
        #expect(policy.minimumInterval == .seconds(60))
        #expect(policy.eventLatency == .seconds(1))
        #expect(policy.busyRetryDelay == .seconds(5))
    }

    @Test
    func anIsolatedChangeIsMeasuredAfterTheQuietPeriod() {
        let due = policy.dueDate(firstChangeAt: start, lastChangeAt: start, measurementStart: nil)

        #expect(due == start.addingTimeInterval(5))
    }

    @Test
    func continuousChangesAreMeasuredAtLeastOnceAMinute() {
        let due = policy.dueDate(
            firstChangeAt: start,
            lastChangeAt: start.addingTimeInterval(58),
            measurementStart: nil
        )

        #expect(due == start.addingTimeInterval(60))
    }

    @Test
    func aRecentMeasurementPostponesTheNextOneToAMinute() {
        let due = policy.dueDate(
            firstChangeAt: start,
            lastChangeAt: start,
            measurementStart: start.addingTimeInterval(-10)
        )

        #expect(due == start.addingTimeInterval(50))
    }

    @Test
    func anOldMeasurementDoesNotPostponeAnything() {
        let due = policy.dueDate(
            firstChangeAt: start,
            lastChangeAt: start,
            measurementStart: start.addingTimeInterval(-600)
        )

        #expect(due == start.addingTimeInterval(5))
    }

    @Test
    func aMeasurementThatStartedAfterTheLastChangeCoversIt() {
        #expect(policy.isCovered(lastChangeAt: start, measurementStart: start.addingTimeInterval(1)))
        #expect(policy.isCovered(lastChangeAt: start, measurementStart: start))
        #expect(!policy.isCovered(lastChangeAt: start, measurementStart: start.addingTimeInterval(-1)))
        #expect(!policy.isCovered(lastChangeAt: start, measurementStart: nil))
    }

    @Test
    func elevenCategoriesAreObserved() {
        #expect(LiveMeasurementPolicy.observedCategoryIDs == [
            .removeDerivedData,
            .removeCaches,
            .removeArchives,
            .clearDeviceSupport,
            .clearSimulatorData,
            .clearAuxiliaryDeviceSets,
            .clearSimulatorCaches,
            .removeSwiftPMCache,
            .removeXcodeProducts,
            .removeXcodeUserData,
            .removeProvisioningProfiles,
        ])
    }

    /// The temporary folders are the noisiest of the system, and the orphans, the old simulators
    /// and the reset take their size from `simctl` or have none: only the complete measurement.
    @Test(arguments: [
        CleanupCategoryID.clearTemporaryFiles,
        .clearOrphanSimulatorTemp,
        .removeOldSimulators,
        .resetXcodePreferences,
    ])
    func theTemporaryAndSimctlCategoriesAreLeftToTheCompleteMeasurement(id: CleanupCategoryID) {
        #expect(!LiveMeasurementPolicy.observedCategoryIDs.contains(id))
    }

    /// A guard against catalog changes: every observed category is measured from its folders alone.
    @Test
    func everyObservedCategoryIsMeasuredFromTheDiskAlone() {
        for category in catalog.categories where LiveMeasurementPolicy.observedCategoryIDs.contains(category.id) {
            #expect(!category.targets.isEmpty, "\(category.id)")
            #expect(category.operation != .removeTemporaryItems, "\(category.id)")
            #expect(category.operation != .removeOrphanSimulatorTemp, "\(category.id)")

            if category.operation.needsSimulatorTools {
                #expect([.clearDeviceSets, .eraseAllSimulators].contains(category.operation), "\(category.id)")
            }
        }
    }

}
