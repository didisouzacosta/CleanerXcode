//
//  CleanupReport+Summary.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

extension CleanupReport {

    // MARK: - Public Properties

    /// The categories that ran without any failure, for "3 of 5 categories" in the hero.
    var finishedCategoryCount: Int {
        let failed = Set(failedCategoryIDs)

        return Set(results.map(\.categoryID)).subtracting(failed).count
    }

    /// The items macOS refused (R13): the notice names the folder when there is only one.
    var permissionDeniedResults: [CleanupItemResult] {
        failedResults.filter { $0.outcome == .failed(.permissionDenied) }
    }

    // MARK: - Public Methods

    /// What failed in one category, for its row.
    func failedResults(of id: CleanupCategoryID) -> [CleanupItemResult] {
        failedResults.filter { $0.categoryID == id }
    }

}
