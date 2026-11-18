//
//  TemporaryItemInspector.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Reads a temporary item without following links. A folder is as recent as the newest thing
/// inside it, and a folder that cannot be read completely, or whose walk is cancelled, counts as
/// recent, so an age that cannot be verified never makes an item look old.
nonisolated struct TemporaryItemInspector: Sendable {

    // MARK: - Private Static Methods

    private static func kind(of type: FileAttributeType?) -> TemporaryItem.Kind {
        switch type {
        case .typeRegular: .file
        case .typeDirectory: .directory
        case .typeSymbolicLink: .symbolicLink
        default: .other
        }
    }

    private static func contents(of folder: URL, modifiedAt date: Date) -> (newest: Date, hasSpecialFiles: Bool) {
        var newest = date
        var hasSpecialFiles = false
        var isComplete = true

        let enumerator = FileManager().enumerator(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileResourceTypeKey],
            options: [],
            errorHandler: { _, _ in
                isComplete = false
                return true
            }
        )

        while let item = enumerator?.nextObject() as? URL {
            guard !Task.isCancelled else { return (.distantFuture, hasSpecialFiles) }

            guard
                let values = try? item.resourceValues(forKeys: [.contentModificationDateKey, .fileResourceTypeKey]),
                let modified = values.contentModificationDate
            else {
                isComplete = false
                continue
            }

            newest = max(newest, modified)

            if let type = values.fileResourceType, ![.regular, .directory, .symbolicLink].contains(type) {
                hasSpecialFiles = true
            }
        }

        return (isComplete ? newest : .distantFuture, hasSpecialFiles)
    }

    // MARK: - Public Methods

    /// `nil` when the item cannot be read, so it is left alone. Without `includingContents`, a
    /// folder is described by itself only, which is enough to rule it out before a full walk.
    func inspect(_ url: URL, includingContents: Bool = true) -> TemporaryItem? {
        let path = URL(filePath: url.path(percentEncoded: false), directoryHint: .notDirectory)
            .path(percentEncoded: false)

        guard
            let attributes = try? FileManager().attributesOfItem(atPath: path),
            let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value,
            let modified = attributes[.modificationDate] as? Date
        else { return nil }

        let kind = Self.kind(of: attributes[.type] as? FileAttributeType)

        guard kind == .directory, includingContents else {
            return TemporaryItem(name: url.lastPathComponent, ownerID: owner, kind: kind, newestModification: modified)
        }

        let contents = Self.contents(of: url, modifiedAt: modified)

        return TemporaryItem(
            name: url.lastPathComponent,
            ownerID: owner,
            kind: kind,
            newestModification: contents.newest,
            containsSpecialFiles: contents.hasSpecialFiles
        )
    }

}
