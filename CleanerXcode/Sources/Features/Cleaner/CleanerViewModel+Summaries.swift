//
//  CleanerViewModel+Summaries.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// Read-only sums of the rows for the interface, kept apart from the view model's intents.
extension CleanerViewModel {

    // MARK: - Public Properties

    /// Every measured category, selected or not: "of 87.7 GB found".
    var foundBytes: Int64 {
        rows.values.reduce(0) { total, row in
            guard case let .measured(bytes) = row else { return total }

            return total + bytes
        }
    }

    /// For "9 of 15 categories measured".
    var measuredCategoryCount: Int {
        rows.values.count { $0 != .measuring }
    }

    var areSimulatorToolsUnavailable: Bool {
        rows.values.contains(.unavailable(.toolsUnavailable))
    }

    // MARK: - Public Methods

    /// The selected part of a section, for its header.
    func selectedBytes(of categories: [CleanupCategory]) -> Int64 {
        categories.reduce(0) { total, category in
            guard selectedIDs.contains(category.id), case let .measured(bytes) = rows[category.id] else {
                return total
            }

            return total + bytes
        }
    }

}
