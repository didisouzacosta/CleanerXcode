//
//  TemporaryItem.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// What the temporary folder policy needs to know about a direct child of a temporary folder.
nonisolated struct TemporaryItem: Sendable, Hashable {

    // MARK: - Public Properties

    let name: String
    let ownerID: uid_t
    let kind: Kind
    /// The newest modification of the item and, for a folder, of everything inside it.
    let newestModification: Date
    /// A socket, pipe or device somewhere inside a folder: a live session may be using it.
    let containsSpecialFiles: Bool

    // MARK: - Initializers

    init(name: String, ownerID: uid_t, kind: Kind, newestModification: Date, containsSpecialFiles: Bool = false) {
        self.name = name
        self.ownerID = ownerID
        self.kind = kind
        self.newestModification = newestModification
        self.containsSpecialFiles = containsSpecialFiles
    }

    // MARK: - Nested Types

    enum Kind: Sendable, Hashable {
        case file
        case directory
        case symbolicLink
        /// Sockets, pipes and devices: never removed.
        case other
    }

}

nonisolated enum TemporaryDecision: Sendable, Hashable {
    case remove
    case skip(CleanupItemResult.SkipReason)
}
