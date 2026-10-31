//
//  DiskUsageScanning.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated protocol DiskUsageScanning: Sendable {
    /// The bytes allocated on disk under `target.root`, leaving out `target.excludedNames`.
    /// A missing root or a root that is a symbolic link measures 0, and a root that cannot be read
    /// throws a `CleanupError` such as `.permissionDenied`. A scan cancelled near its end may still
    /// return, so callers check cancellation before using the result.
    func allocatedSize(of target: CleanupTarget) async throws -> Int64
}
