//
//  ItemSizeReader.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The size of one item: a folder through the scanner, a link 0 and a file its own allocation.
nonisolated struct ItemSizeReader: Sendable {

    // MARK: - Public Properties

    let scanner: any DiskUsageScanning

    // MARK: - Initializers

    init(scanner: any DiskUsageScanning = FileSystemSizeScanner()) {
        self.scanner = scanner
    }

    // MARK: - Public Methods

    /// A size that cannot be read counts 0; cancellation propagates.
    func allocatedSize(of item: URL) async throws -> Int64 {
        let path = item.path(percentEncoded: false)

        guard let type = try? FileManager().attributesOfItem(atPath: path)[.type] as? FileAttributeType else {
            return 0
        }

        switch type {
        case .typeDirectory:
            do {
                return try await scanner.allocatedSize(of: CleanupTarget(root: item))
            } catch let error as CancellationError {
                throw error
            } catch {
                return 0
            }

        case .typeSymbolicLink:
            return 0

        default:
            let fresh = URL(filePath: path, directoryHint: .notDirectory)
            let values = try? fresh.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
    }

}
