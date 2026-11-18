//
//  CategorySize.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated struct CategorySize: Sendable, Hashable {

    // MARK: - Public Properties

    let categoryID: CleanupCategoryID
    /// The sum of the targets that could be measured.
    let bytes: Int64
    /// The first failure among the targets, whose bytes are left out of `bytes`.
    let failure: CleanupError?

    // MARK: - Initializers

    init(categoryID: CleanupCategoryID, bytes: Int64, failure: CleanupError? = nil) {
        self.categoryID = categoryID
        self.bytes = bytes
        self.failure = failure
    }

}
