//
//  SidebarDestination.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The pages of the window's sidebar (Figma page 08), in order, with the Settings pages since C40.
/// Kept per window by its raw value in `@SceneStorage`, so its cases must keep their names: new
/// pages only add cases.
enum SidebarDestination: String, CaseIterable, Hashable, Identifiable {

    // MARK: - Cases

    case overview
    case xcode
    case simulators
    case temporary
    case userData
    case simulatorsAndRuntimes
    case general
    case about

    // MARK: - Public Properties

    var id: String {
        rawValue
    }

    var section: CleanerSection? {
        switch self {
        case .overview, .simulatorsAndRuntimes, .general, .about: nil
        case .xcode: .xcode
        case .simulators: .simulators
        case .temporary: .temporary
        case .userData: .userData
        }
    }

    var group: Group {
        switch self {
        case .overview: .top
        case .xcode, .simulators, .temporary, .userData: .cleanup
        case .simulatorsAndRuntimes: .manage
        case .general, .about: .settings
        }
    }

    /// The action bar and Refresh only exist on the cleanup pages; Settings has neither (C40).
    var showsCleanupControls: Bool {
        group != .settings
    }

    /// The page title in the toolbar.
    var title: LocalizedStringResource {
        switch self {
        case .overview: "Overview"
        case .simulatorsAndRuntimes: "Simulators and runtimes"
        case .general: "General"
        case .about: "About"
        case .xcode, .simulators, .temporary, .userData: section?.title ?? "Overview"
        }
    }

    /// The sidebar row and the View menu use the short section title.
    var sidebarTitle: LocalizedStringResource {
        section?.shortTitle ?? title
    }

    var systemImage: String {
        switch self {
        case .overview: "rays"
        case .simulatorsAndRuntimes: "iphone"
        case .general: "gearshape"
        case .about: "info.circle"
        case .xcode, .simulators, .temporary, .userData: section?.systemImage ?? "rays"
        }
    }

    /// ⌘1 to ⌘8, in the sidebar order.
    var shortcutDigit: Int {
        switch self {
        case .overview: 1
        case .xcode: 2
        case .simulators: 3
        case .temporary: 4
        case .userData: 5
        case .simulatorsAndRuntimes: 6
        case .general: 7
        case .about: 8
        }
    }

    // MARK: - Initializers

    init(section: CleanerSection) {
        switch section {
        case .xcode: self = .xcode
        case .simulators: self = .simulators
        case .temporary: self = .temporary
        case .userData: self = .userData
        }
    }

    // MARK: - Public Methods

    static func destinations(in group: Group) -> [SidebarDestination] {
        allCases.filter { $0.group == group }
    }

    // MARK: - Nested Types

    /// "Overview" alone, then the "Cleanup", "Manage" and "Settings" labels.
    enum Group: Hashable {
        case top
        case cleanup
        case manage
        case settings
    }

}
