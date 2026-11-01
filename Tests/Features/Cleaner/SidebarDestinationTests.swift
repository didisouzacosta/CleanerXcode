//
//  SidebarDestinationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The pages of the sidebar (Figma page 08): their stored value, order, groups, sections,
/// shortcuts and titles.
struct SidebarDestinationTests {

    // MARK: - Public Methods

    /// Kept per window in `@SceneStorage` by its raw value.
    @Test
    func roundTripsThroughItsStoredValue() {
        for destination in SidebarDestination.allCases {
            #expect(SidebarDestination(rawValue: destination.rawValue) == destination)
        }

        #expect(SidebarDestination(rawValue: "manage-simulators") == nil)
    }

    @Test
    func keepsTheSidebarOrderAndGroups() {
        #expect(SidebarDestination.allCases == [
            .overview,
            .xcode,
            .simulators,
            .temporary,
            .userData,
            .simulatorsAndRuntimes,
        ])
        #expect(SidebarDestination.destinations(in: .top) == [.overview])
        #expect(SidebarDestination.destinations(in: .cleanup) == [.xcode, .simulators, .temporary, .userData])
        #expect(SidebarDestination.destinations(in: .manage) == [.simulatorsAndRuntimes])
    }

    @Test
    func mapsEachCleanupPageToItsSection() {
        #expect(SidebarDestination.overview.section == nil)
        #expect(SidebarDestination.simulatorsAndRuntimes.section == nil)
        #expect(SidebarDestination.destinations(in: .cleanup).compactMap(\.section) == CleanerSection.allCases)

        for section in CleanerSection.allCases {
            #expect(SidebarDestination(section: section).section == section)
        }
    }

    /// ⌘1 to ⌘6, in the sidebar order.
    @Test
    func eachPageHasItsOwnShortcutDigit() {
        #expect(SidebarDestination.allCases.map(\.shortcutDigit) == [1, 2, 3, 4, 5, 6])
    }

    /// The page title is the section title; the sidebar uses the short one.
    @Test
    func eachPageHasATitle() {
        #expect(SidebarDestination.overview.title.key == "Overview")
        #expect(SidebarDestination.simulatorsAndRuntimes.title.key == "Simulators and runtimes")
        #expect(SidebarDestination.userData.title.key == "User data and reset")
        #expect(SidebarDestination.userData.sidebarTitle.key == "User data")
        #expect(SidebarDestination.xcode.sidebarTitle.key == "Xcode")

        for destination in SidebarDestination.allCases {
            #expect(!destination.systemImage.isEmpty, "\(destination)")
        }
    }

}
