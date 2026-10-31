//
//  FileOperating.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The two destructive primitives, kept apart so tests never touch the real Trash.
nonisolated protocol FileOperating: Sendable {
    /// Removes the item; a symbolic link is removed without following it.
    func delete(_ url: URL) throws
    func moveToTrash(_ url: URL) throws
}

nonisolated struct FileManagerOperations: FileOperating {

    // MARK: - Public Methods

    func delete(_ url: URL) throws {
        try FileManager().removeItem(at: url)
    }

    func moveToTrash(_ url: URL) throws {
        try FileManager().trashItem(at: url, resultingItemURL: nil)
    }

}
