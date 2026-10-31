//
//  CleanerSectionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CleanerSectionTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))

    // MARK: - Public Methods

    @Test
    func groupsEveryCategoryOnceInTheApprovedOrder() {
        let sections = CleanerSection.grouping(catalog.categories)
        let ids = sections.flatMap { $0.categories.map(\.id) }

        #expect(sections.map(\.section) == [.xcode, .simulators, .temporary, .userData])
        #expect(ids.count == catalog.categories.count)
        #expect(Set(ids) == Set(CleanupCategoryID.allCases))
        #expect(sections[0].categories.map(\.id) == [
            .removeDerivedData,
            .removeCaches,
            .clearDeviceSupport,
            .removeSwiftPMCache,
            .removeXcodeProducts,
        ])
        #expect(sections[1].categories.map(\.id) == [
            .clearOrphanSimulatorTemp,
            .clearSimulatorCaches,
            .clearAuxiliaryDeviceSets,
            .removeOldSimulators,
            .clearSimulatorData,
        ])
        #expect(sections[2].categories.map(\.id) == [.clearTemporaryFiles])
        #expect(sections[3].categories.map(\.id) == [
            .removeArchives,
            .removeXcodeUserData,
            .removeProvisioningProfiles,
            .resetXcodePreferences,
        ])
    }

    /// The risk never goes down inside a section, so the dangerous items come last.
    @Test
    func theRiskierItemsComeLastInEachSection() {
        for group in CleanerSection.grouping(catalog.categories) {
            let risks = group.categories.map(\.risk)

            #expect(risks == risks.sorted(), "\(group.section)")
        }
    }

    @Test
    func aSectionMissingFromTheCatalogIsLeftOut() {
        let sections = CleanerSection.grouping([catalog[.clearTemporaryFiles]])

        #expect(sections.map(\.section) == [.temporary])
    }

    @Test
    func everyCategoryHasATitleASubtitleAndASymbol() {
        for id in CleanupCategoryID.allCases {
            let presentation = CategoryPresentation(id)

            #expect(!String(localized: presentation.title).isEmpty, "\(id)")
            #expect(!String(localized: presentation.subtitle).isEmpty, "\(id)")
            #expect(!presentation.systemImage.isEmpty, "\(id)")
        }
    }

}
