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
    /// It runs in the caller's task: `onResult` is called on the caller's actor, before the next
    /// item starts, and the disk work runs off it. Every completed removal is reported even when
    /// the caller is cancelled. It only throws `CancellationError`, between items.
    func removeContents(
        of target: CleanupTarget,
        categoryID: CleanupCategoryID,
        mode: RemovalMode,
        filter: @escaping @Sendable (URL) -> Bool,
        onResult: (CleanupItemResult) -> Void
    ) async throws
}
