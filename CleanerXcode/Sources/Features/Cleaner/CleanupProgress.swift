//
//  CleanupProgress.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated struct CleanupProgress: Sendable, Hashable {

    // MARK: - Public Properties

    let totalCategories: Int

    var startedCategories = 0
    var currentCategory: CleanupCategoryID?
    var finishedItems = 0
    var freedBytes: Int64 = 0
    /// Moved to the Trash: only freed once the Trash is emptied, like in the report.
    var trashedBytes: Int64 = 0

    // MARK: - Public Methods

    /// What each executor event changes in the hero's numbers while cleaning.
    mutating func apply(_ event: CleanupEvent) {
        switch event {
        case let .categoryStarted(id):
            startedCategories += 1
            currentCategory = id

        case let .itemFinished(result):
            finishedItems += 1

            if result.outcome == .removed {
                freedBytes += result.bytes
            } else if result.outcome == .trashed {
                trashedBytes += result.bytes
            }

        case .closingSimulators, .restartingSimulatorService:
            break
        }
    }

}
