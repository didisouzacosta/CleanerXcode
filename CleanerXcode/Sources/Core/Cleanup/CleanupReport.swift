//
//  CleanupReport.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Pure aggregation of a cleanup. It is a success only when nothing failed: showing success while
/// something failed is forbidden (R6).
nonisolated struct CleanupReport: Sendable, Hashable {

    // MARK: - Public Properties

    let results: [CleanupItemResult]
    let outcome: Outcome
    let freedBytes: Int64
    /// Moved to the Trash: only freed after the Trash is emptied.
    let trashedBytes: Int64

    var failedResults: [CleanupItemResult] {
        results.filter(\.isFailure)
    }

    /// In the order they first failed, without repetition.
    var failedCategoryIDs: [CleanupCategoryID] {
        var ids: [CleanupCategoryID] = []

        for result in failedResults where !ids.contains(result.categoryID) {
            ids.append(result.categoryID)
        }

        return ids
    }

    // MARK: - Initializers

    init(results: [CleanupItemResult], wasCancelled: Bool = false) {
        var freedBytes: Int64 = 0
        var trashedBytes: Int64 = 0
        var attemptedCount = 0
        var failedCount = 0

        for result in results {
            switch result.outcome {
            case .removed:
                freedBytes += result.bytes
                attemptedCount += 1

            case .trashed:
                trashedBytes += result.bytes
                attemptedCount += 1

            case .failed:
                failedCount += 1
                attemptedCount += 1

            case .skipped:
                break
            }
        }

        self.results = results
        self.freedBytes = freedBytes
        self.trashedBytes = trashedBytes
        self.outcome = if wasCancelled {
            .cancelled
        } else if failedCount == 0 {
            .success
        } else if failedCount == attemptedCount {
            .failure
        } else {
            .partialFailure
        }
    }

    // MARK: - Nested Types

    enum Outcome: Sendable, Hashable {
        case success
        case partialFailure
        case failure
        case cancelled
    }

}
