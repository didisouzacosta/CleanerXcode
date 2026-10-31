//
//  CleanupPlan.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// The categories the user confirmed, in catalog order, and the settings they depend on.
nonisolated struct CleanupPlan: Sendable, Hashable {

    // MARK: - Public Properties

    let categories: [CleanupCategory]
    /// D7, from Settings: temporary items younger than this are kept.
    let minimumTemporaryAgeInDays: Int

    // MARK: - Initializers

    init(categories: [CleanupCategory], minimumTemporaryAgeInDays: Int = TemporaryItemsPolicy.defaultMinimumAgeInDays) {
        self.categories = categories
        self.minimumTemporaryAgeInDays = minimumTemporaryAgeInDays
    }

}

/// Progress, in the order it happens.
nonisolated enum CleanupEvent: Sendable, Hashable {
    case closingSimulators
    case categoryStarted(CleanupCategoryID)
    case itemFinished(CleanupItemResult)
    case restartingSimulatorService
}
