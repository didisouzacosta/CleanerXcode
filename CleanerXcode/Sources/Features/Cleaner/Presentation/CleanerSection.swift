//
//  CleanerSection.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The cleanup sections, in the approved order (Figma pages 03 and 08): Xcode, Simulators,
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

    /// The sidebar, the menu and the space legend use the short title (Figma page 08).
    var shortTitle: LocalizedStringResource {
        switch self {
        case .userData: "User data"
        case .xcode, .simulators, .temporary: title
        }
    }

    var systemImage: String {
        switch self {
        case .xcode: "square.stack.3d.up"
        case .simulators: "macbook.and.iphone"
        case .temporary: "clock"
        case .userData: "person"
        }
    }

    var categoryIDs: [CleanupCategoryID] {
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
