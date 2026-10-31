//
//  FileSystemRemover.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Removes the contents of a cleanup target natively. Every child goes through the
/// `SafePathPolicy` right before it is removed, and each one produces its own result, so a single
/// failure never hides behind a success (R6) and cancellation stops between items (R7). The work
/// runs in the caller's task, off its actor, so a cancelled caller still gets every result.
nonisolated struct FileSystemRemover: FileRemoving {

    // MARK: - Private Properties

    private let policy: SafePathPolicy
    private let locations: CleanupLocations
    private let operations: any FileOperating
    private let sizeReader: ItemSizeReader

    // MARK: - Initializers

    init(
        policy: SafePathPolicy,
        locations: CleanupLocations,
        operations: any FileOperating = FileManagerOperations(),
        scanner: any DiskUsageScanning = FileSystemSizeScanner()
    ) {
        self.policy = policy
        self.locations = locations
        self.operations = operations
        self.sizeReader = ItemSizeReader(scanner: scanner)
    }

    // MARK: - Private Static Methods

    /// Built from the names, without a trailing slash, so a symlinked folder is never followed.
    private static func children(of target: CleanupTarget) throws -> [URL] {
        try FileManager().contentsOfDirectory(atPath: target.root.path(percentEncoded: false))
            .filter { !target.excludedNames.contains($0) }
            .sorted()
            .map { target.root.appending(path: $0, directoryHint: .notDirectory) }
    }

    /// So the root reads like its children in the report.
    private static func withoutTrailingSlash(_ url: URL) -> URL {
        url.deletingLastPathComponent().appending(path: url.lastPathComponent, directoryHint: .notDirectory)
    }

    // MARK: - Public Methods

    @concurrent
    func removeContents(
        of target: CleanupTarget,
        categoryID: CleanupCategoryID,
        mode: RemovalMode,
        filter: @Sendable (URL) -> Bool,
        onResult: @Sendable (CleanupItemResult) -> Void
    ) async throws {
        try Task.checkCancellation()

        let children: [URL]

        do {
            try policy.validateRoot(target)
            children = try Self.children(of: target)
        } catch {
            let cleanupError = CleanupError(error)

            // A missing root has nothing to remove.
            guard cleanupError != .notFound else { return }

            onResult(result(
                for: Self.withoutTrailingSlash(target.root),
                categoryID: categoryID,
                bytes: 0,
                outcome: .failed(cleanupError)
            ))
            return
        }

        for child in children {
            // Before the filter, which may read the disk (the temporary folder filters do).
            try Task.checkCancellation()

            guard filter(child) else { continue }

            try await onResult(remove(child, in: target, categoryID: categoryID, mode: mode))
        }
    }

    // MARK: - Private Methods

    private func remove(
        _ child: URL,
        in target: CleanupTarget,
        categoryID: CleanupCategoryID,
        mode: RemovalMode
    ) async throws -> CleanupItemResult {
        do {
            try policy.validate(child, in: target)

            let bytes = try await sizeReader.allocatedSize(of: child)

            // The scan may return even when cancelled near its end, so check before removing.
            try Task.checkCancellation()

            switch mode {
            case .delete:
                try operations.delete(child)
                return result(for: child, categoryID: categoryID, bytes: bytes, outcome: .removed)

            case .trash:
                try operations.moveToTrash(child)
                return result(for: child, categoryID: categoryID, bytes: bytes, outcome: .trashed)
            }
        } catch let error as CancellationError {
            throw error
        } catch {
            return result(for: child, categoryID: categoryID, bytes: 0, outcome: .failed(CleanupError(error)))
        }
    }

    private func result(
        for url: URL,
        categoryID: CleanupCategoryID,
        bytes: Int64,
        outcome: CleanupItemResult.Outcome
    ) -> CleanupItemResult {
        CleanupItemResult(
            categoryID: categoryID,
            displayPath: locations.displayPath(for: url),
            bytes: bytes,
            outcome: outcome
        )
    }

}
