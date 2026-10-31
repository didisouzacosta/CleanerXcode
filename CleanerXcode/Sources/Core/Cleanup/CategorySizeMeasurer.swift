//
//  CategorySizeMeasurer.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Measures the categories in parallel. Each result reaches `onResult` on the caller's actor as
/// soon as its category is done, so the screen fills in without waiting for the slowest folder.
nonisolated struct CategorySizeMeasurer: Sendable {

    // MARK: - Public Properties

    let scanner: any DiskUsageScanning

    // MARK: - Private Static Methods

    /// Measures the targets of one category in order. A failed target is left out of the sum, and
    /// cancellation always propagates.
    private static func measure(_ category: CleanupCategory, using scanner: any DiskUsageScanning) async throws
        -> CategorySize
    {
        var bytes: Int64 = 0
        var failure: CleanupError?

        for target in category.targets {
            do {
                bytes += try await scanner.allocatedSize(of: target)
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

    // MARK: - Public Methods

    /// Categories without targets (sized by `simctl` instead) produce no result.
    func measure(
        _ categories: [CleanupCategory],
        isolation: isolated (any Actor)? = #isolation,
        onResult: (CategorySize) -> Void
    ) async throws {
        let scanner = scanner

        try await withThrowingTaskGroup(of: CategorySize.self, isolation: isolation) { group in
            // A closure only runs on an `isolated` parameter's actor when it captures it (SE-0420),
            // and this keeps every `onResult` call on the caller's actor.
            _ = isolation

            for category in categories where !category.targets.isEmpty {
                group.addTask {
                    try await Self.measure(category, using: scanner)
                }
            }

            for try await result in group {
                try Task.checkCancellation()
                onResult(result)
            }
        }
    }

}
