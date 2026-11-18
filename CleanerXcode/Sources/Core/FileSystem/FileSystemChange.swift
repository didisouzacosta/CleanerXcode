//
//  FileSystemChange.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

/// A directory the file system reported as changed (C40 · tempo real).
nonisolated struct FileSystemChange: Sendable, Equatable {

    // MARK: - Public Properties

    /// The real path, as the system reports it (for example `/private/var/...`).
    let path: String
    let kind: Kind

    // MARK: - Nested Types

    enum Kind: Sendable, Equatable {
        /// Something inside the directory changed.
        case changed
        /// A watched root, or one of its parents, was created, removed or renamed.
        case rootChanged
        /// Events were coalesced or dropped: anything under the path may have changed.
        case mustRescan
    }

}
