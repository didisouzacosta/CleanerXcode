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

}
