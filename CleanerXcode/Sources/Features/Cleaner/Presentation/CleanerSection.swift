//
//  CleanerSection.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The groups of the main list, in the approved order (Figma, page 03): Xcode, Simulators,
/// Temporary files, and User data and reset. Inside each group the riskier items come last.
enum CleanerSection: String, CaseIterable, Identifiable {

    // MARK: - Cases

    case xcode
    case simulators
    case temporary
    case userData

    // MARK: - Public Properties

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .xcode: "Xcode"
        case .simulators: "Simulators"
        case .temporary: "Temporary files"
        case .userData: "User data and reset"
        }
    }

    /// Kept per section, so a collapsed section stays collapsed (owner adjustment to C01).
    var collapsedStorageKey: String {
        "section-collapsed-\(rawValue)"
    }

    // MARK: - Private Properties

    private var categoryIDs: [CleanupCategoryID] {
        switch self {
        case .xcode:
            [.removeDerivedData, .removeCaches, .clearDeviceSupport, .removeSwiftPMCache, .removeXcodeProducts]

        case .simulators:
            [
                .clearOrphanSimulatorTemp,
                .clearSimulatorCaches,
                .clearAuxiliaryDeviceSets,
                .removeOldSimulators,
                .clearSimulatorData,
            ]

        case .temporary:
            [.clearTemporaryFiles]

        case .userData:
            [.removeArchives, .removeXcodeUserData, .removeProvisioningProfiles, .resetXcodePreferences]
        }
    }

    // MARK: - Public Methods

    /// The sections that have categories, each in its fixed order; empty sections are left out.
    static func grouping(_ categories: [CleanupCategory]) -> [Group] {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        return allCases.compactMap { section in
            let members = section.categoryIDs.compactMap { byID[$0] }
            return members.isEmpty ? nil : Group(section: section, categories: members)
        }
    }

    // MARK: - Nested Types

    struct Group: Identifiable {

        // MARK: - Public Properties

        let section: CleanerSection
        let categories: [CleanupCategory]

        var id: CleanerSection {
            section
        }

    }

}
