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

}
