//
//  SidebarDestinationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit
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
            .general,
            .about,
        ])
        #expect(SidebarDestination.destinations(in: .top) == [.overview])
        #expect(SidebarDestination.destinations(in: .cleanup) == [.xcode, .simulators, .temporary, .userData])
        #expect(SidebarDestination.destinations(in: .manage) == [.simulatorsAndRuntimes])
        #expect(SidebarDestination.destinations(in: .settings) == [.general, .about])
    }

    /// The saved pages keep their names (C40): only `general` and `about` are new.
    @Test
    func keepsTheStoredValuesOfEveryPage() {
        #expect(SidebarDestination.allCases.map(\.rawValue) == [
            "overview",
            "xcode",
            "simulators",
            "temporary",
            "userData",
            "simulatorsAndRuntimes",
            "general",
            "about",
        ])
    }

    /// The Settings pages (C40) have no action bar, no Refresh and no section.
    @Test
    func onlyTheSettingsPagesHideTheCleanupControls() {
        let settings: [SidebarDestination] = [.general, .about]

        for destination in SidebarDestination.allCases {
            #expect(destination.showsCleanupControls == !settings.contains(destination), "\(destination)")
        }

        #expect(SidebarDestination.general.section == nil)
        #expect(SidebarDestination.about.section == nil)
        #expect(SidebarDestination.general.title.key == "General")
        #expect(SidebarDestination.about.title.key == "About")
        #expect(SidebarDestination.general.sidebarTitle.key == "General")
        #expect(SidebarDestination.about.sidebarTitle.key == "About")
        #expect(SidebarDestination.general.systemImage == "gearshape")
        #expect(SidebarDestination.about.systemImage == "info.circle")
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

    /// A dashboard gauge, not the old rays that read as a loading spinner; the symbol exists on
    /// the system, so the row never shows an empty icon.
    @Test
    func showsTheOverviewAsADashboardGauge() {
        #expect(SidebarDestination.overview.systemImage == "gauge.with.dots.needle.67percent")

        for destination in SidebarDestination.allCases {
            #expect(
                NSImage(systemSymbolName: destination.systemImage, accessibilityDescription: nil) != nil,
                "\(destination)"
            )
        }
    }

    /// ⌘1 to ⌘8, in the sidebar order.
    @Test
    func eachPageHasItsOwnShortcutDigit() {
        #expect(SidebarDestination.allCases.map(\.shortcutDigit) == Array(1...8))
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
