//
//  FileSystemSizeScanner.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import os

/// Measures the space a cleanup target takes on disk, natively and without `du`. It never follows
/// symbolic links and checks for cancellation before starting and every `cancellationCheckInterval`
/// items, so a scan cancelled during its last partial batch may still return; callers check
/// cancellation before using the result.
nonisolated struct FileSystemSizeScanner: DiskUsageScanning {

    // MARK: - Public Properties

    static let cancellationCheckInterval = 500

    // MARK: - Private Properties

    private static let resourceKeys: [URLResourceKey] = [
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .fileResourceTypeKey,
    ]

    private static let logger = Logger(subsystem: "com.didisouzacosta.CleanerXcode", category: "DiskUsage")

    private let makeFileManager: @Sendable () -> FileManager

    // MARK: - Initializers

    init(makeFileManager: @escaping @Sendable () -> FileManager = { FileManager() }) {
        self.makeFileManager = makeFileManager
    }

    // MARK: - Private Static Methods

    /// The directory enumeration is synchronous, so it stays out of the async context.
    private static func measure(_ target: CleanupTarget, using fileManager: FileManager) throws -> Int64 {
        let rootPath = normalizedPath(of: target.root)

        guard try isMeasurableRoot(atPath: rootPath, using: fileManager) else { return 0 }

        var rootError: (any Error)?
        var unreadableItemCount = 0

        let enumerator = fileManager.enumerator(
            at: target.root,
            includingPropertiesForKeys: resourceKeys,
            options: [],
            errorHandler: { url, error in
                guard normalizedPath(of: url) != rootPath else {
                    rootError = error
                    return false
                }

                unreadableItemCount += 1
                return true
            }
        )

        var total: Int64 = 0
        var visitedCount = 0

        while let item = enumerator?.nextObject() as? URL {
            visitedCount += 1

            if visitedCount.isMultiple(of: cancellationCheckInterval) {
                try Task.checkCancellation()
            }

            if enumerator?.level == 1, target.excludedNames.contains(item.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }

            guard let values = try? item.resourceValues(forKeys: Set(resourceKeys)) else {
                unreadableItemCount += 1
                continue
            }

            // Directories report no allocated size and links are never followed.
            guard values.isSymbolicLink != true, values.isDirectory != true else { continue }

            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        if let rootError {
            let error = CleanupError(rootError)

            guard error == .notFound else { throw error }

            return 0
        }

        if unreadableItemCount > 0 {
            logger.notice("Measured without \(unreadableItemCount, privacy: .public) unreadable items")
        }

        return total
    }

    /// A missing root measures 0, and a root that is a symbolic link is skipped as the cleanup does.
    private static func isMeasurableRoot(atPath path: String, using fileManager: FileManager) throws -> Bool {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return attributes[.type] as? FileAttributeType != .typeSymbolicLink
        } catch {
            let cleanupError = CleanupError(error)

            guard cleanupError == .notFound else { throw cleanupError }

            return false
        }
    }

    private static func normalizedPath(of url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)

        guard path.count > 1, path.hasSuffix("/") else { return path }

        return String(path.dropLast())
    }

    // MARK: - Public Methods

    @concurrent
    func allocatedSize(of target: CleanupTarget) async throws -> Int64 {
        try Task.checkCancellation()

        return try Self.measure(target, using: makeFileManager())
    }

}
