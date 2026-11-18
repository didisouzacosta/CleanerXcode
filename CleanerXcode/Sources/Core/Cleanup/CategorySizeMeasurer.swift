//
//  CategorySizeMeasurer.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Measures the categories in parallel. Each result reaches `onResult` on the caller's actor as
/// soon as its category is done, so the screen fills in without waiting for the slowest folder.
nonisolated struct CategorySizeMeasurer: Sendable {

    // MARK: - Public Properties

    let scanner: any DiskUsageScanning

    // MARK: - Private Static Methods

    /// Measures the targets of one category in order. A failed target is left out of the sum, and
    /// cancellation always propagates.
    private static func measure(
        _ category: CleanupCategory,
        using scanner: any DiskUsageScanning,
        filter: (@Sendable (URL) -> Bool)?
    ) async throws -> CategorySize {
        var bytes: Int64 = 0
        var failure: CleanupError?

        for target in category.targets {
            do {
                if let filter {
                    bytes += try await FilteredContentsMeasurer(scanner: scanner).allocatedSize(
                        of: target,
                        filter: filter
                    )
                } else {
                    bytes += try await scanner.allocatedSize(of: target)
                }
            } catch {
                let cleanupError = CleanupError(error)

                if cleanupError == .cancelled {
                    throw CancellationError()
                }

                failure = failure ?? cleanupError
            }
        }

        return CategorySize(categoryID: category.id, bytes: bytes, failure: failure)
    }

    private static func needsFilter(_ operation: CleanupOperation) -> Bool {
        switch operation {
        case .removeTemporaryItems, .removeOrphanSimulatorTemp: true
        default: false
        }
    }

    // MARK: - Public Methods

    /// Categories without targets (sized by `simctl` instead) produce no result. A category with a
    /// filter only counts the children the filter accepts, and the temporary categories produce
    /// no result without their filter.
    func measure(
        _ categories: [CleanupCategory],
        filters: [CleanupCategoryID: @Sendable (URL) -> Bool] = [:],
        isolation: isolated (any Actor)? = #isolation,
        onResult: (CategorySize) -> Void
    ) async throws {
        let scanner = scanner

        try await withThrowingTaskGroup(of: CategorySize.self, isolation: isolation) { group in
            // A closure only runs on an `isolated` parameter's actor when it captures it (SE-0420),
            // and this keeps every `onResult` call on the caller's actor.
            _ = isolation

            for category in categories where !category.targets.isEmpty {
                // Measured raw, a temporary folder would count far more than it removes.
                guard filters[category.id] != nil || !Self.needsFilter(category.operation) else { continue }

                group.addTask {
                    try await Self.measure(category, using: scanner, filter: filters[category.id])
                }
            }

            for try await result in group {
                try Task.checkCancellation()
                onResult(result)
            }
        }
    }

}
