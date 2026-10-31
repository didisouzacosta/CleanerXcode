//
//  FilteredContentsMeasurer.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Measures only the direct children a filter accepts, for the categories whose roots hold far
/// more than what they remove, such as the temporary folders.
nonisolated struct FilteredContentsMeasurer: Sendable {

    // MARK: - Private Properties

    private let sizeReader: ItemSizeReader

    // MARK: - Initializers

    init(scanner: any DiskUsageScanning = FileSystemSizeScanner()) {
        self.sizeReader = ItemSizeReader(scanner: scanner)
    }

    // MARK: - Public Methods

    /// A missing root or a root that is a symbolic link measures 0, like the scanner; a root that
    /// cannot be listed throws its `CleanupError`.
    @concurrent
    func allocatedSize(of target: CleanupTarget, filter: @Sendable (URL) -> Bool) async throws -> Int64 {
        let rootPath = target.root.path(percentEncoded: false)
        let names: [String]

        do {
            let attributes = try FileManager().attributesOfItem(atPath: rootPath)

            guard attributes[.type] as? FileAttributeType != .typeSymbolicLink else { return 0 }

            names = try FileManager().contentsOfDirectory(atPath: rootPath)
        } catch {
            let cleanupError = CleanupError(error)

            guard cleanupError == .notFound else { throw cleanupError }

            return 0
        }

        var total: Int64 = 0

        for name in names.sorted() where !target.excludedNames.contains(name) {
            let child = target.root.appending(path: name, directoryHint: .notDirectory)

            try Task.checkCancellation()

            guard filter(child) else { continue }

            total += try await sizeReader.allocatedSize(of: child)
        }

        return total
    }

}
