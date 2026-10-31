//
//  FileRemoving.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated protocol FileRemoving: Sendable {
    /// Removes the direct children of `target.root` one by one, keeping the root, and hands one
    /// result per child to `onResult`. Children in `target.excludedNames` or rejected by `filter`
    /// are left alone and not reported.
    ///
    /// It runs off the caller's actor in the caller's task. Each result is delivered before the
    /// next item starts, so every completed removal is reported even when the caller is cancelled.
    /// It only throws `CancellationError`, between items.
    func removeContents(
        of target: CleanupTarget,
        categoryID: CleanupCategoryID,
        mode: RemovalMode,
        filter: @Sendable (URL) -> Bool,
        onResult: @Sendable (CleanupItemResult) -> Void
    ) async throws
}
