//
//  CleanerNotice.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// The fixed notices (plan section 2.4) and the pages that show each one (Figma page 08): the
/// overview shows them all, and each page only the ones about its own items.
enum CleanerNotice: Hashable, Identifiable {

    // MARK: - Cases

    case permissionDenied
    case xcodeOpen
    case simulatorsOpen
    case toolsUnavailable
    case trashBound

    // MARK: - Public Properties

    var id: Self {
        self
    }

    // MARK: - Public Methods

    static func notices(
        for destination: SidebarDestination,
        phase: CleanerPhase,
        restrictions: CleanupRestrictions,
        areSimulatorToolsUnavailable: Bool,
        trashBound: Set<CleanupCategoryID>
    ) -> [CleanerNotice] {
        var notices: [CleanerNotice] = []

        if destination == .overview, case .permissionDenied = phase {
            notices.append(.permissionDenied)
        }

        if restrictions.isXcodeRunning, [.overview, .xcode, .userData].contains(destination) {
            notices.append(.xcodeOpen)
        }

        let isAboutSimulators = [.overview, .simulators, .simulatorsAndRuntimes].contains(destination)

        if restrictions.areSimulatorsActive, isAboutSimulators {
            notices.append(.simulatorsOpen)
        }

        if areSimulatorToolsUnavailable, isAboutSimulators {
            notices.append(.toolsUnavailable)
        }

        if showsTrashNotice(on: destination, trashBound: trashBound) {
            notices.append(.trashBound)
        }

        return notices
    }

    // MARK: - Private Methods

    private static func showsTrashNotice(
        on destination: SidebarDestination,
        trashBound: Set<CleanupCategoryID>
    ) -> Bool {
        guard !trashBound.isEmpty else { return false }

        guard destination != .overview else { return true }

        return destination.section.map { !trashBound.isDisjoint(with: $0.categoryIDs) } ?? false
    }

}
