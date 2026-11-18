//
//  RemovalMode.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Dangerous items go to the Trash, so the space is only freed when the Trash is emptied.
nonisolated enum RemovalMode: Sendable, Hashable {
    case delete
    case trash
}
