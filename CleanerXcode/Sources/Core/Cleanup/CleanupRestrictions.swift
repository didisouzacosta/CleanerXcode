//
//  CleanupRestrictions.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// What the running apps prevent or put at risk (R5): with Xcode open its own settings are
/// blocked and DerivedData warns, and with simulators active every category that shuts them down
/// warns that they will close. Derived from the catalog flags only.
nonisolated struct CleanupRestrictions: Sendable, Hashable {

    // MARK: - Public Properties

    let blockedCategoryIDs: Set<CleanupCategoryID>
    let warnings: [CleanupCategoryID: Warning]

    // MARK: - Initializers

    init(categories: [CleanupCategory], isXcodeRunning: Bool, areSimulatorsActive: Bool) {
        var blocked: Set<CleanupCategoryID> = []
        var warnings: [CleanupCategoryID: Warning] = [:]

        for category in categories {
            if isXcodeRunning, category.isBlockedWhileXcodeRuns {
                blocked.insert(category.id)
            } else if isXcodeRunning, category.warnsWhileXcodeRuns {
                warnings[category.id] = .xcodeIsRunning
            } else if areSimulatorsActive, category.shutsDownSimulators {
                warnings[category.id] = .simulatorsWillClose
            }
        }

        self.blockedCategoryIDs = blocked
        self.warnings = warnings
    }

    // MARK: - Public Methods

    func isBlocked(_ id: CleanupCategoryID) -> Bool {
        blockedCategoryIDs.contains(id)
    }

    // MARK: - Nested Types

    enum Warning: Sendable, Hashable {
        /// "Feche o Xcode" is advised: it may rebuild while cleaning.
        case xcodeIsRunning
        /// Simulator.app and the booted devices will be shut down first.
        case simulatorsWillClose
    }

}
