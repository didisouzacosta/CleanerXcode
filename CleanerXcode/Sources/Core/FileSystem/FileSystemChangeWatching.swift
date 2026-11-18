//
//  FileSystemChangeWatching.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

/// Reports which directories change under a set of folders (C40 · tempo real).
nonisolated protocol FileSystemChangeWatching: Sendable {
    /// Batches of changed directories under `directories`, at most one per `latency`. The stream
    /// ends, and the system stream is released, when the consumer stops iterating; it ends at once
    /// when nothing can be watched.
    func changes(under directories: [String], latency: Duration) -> AsyncStream<[FileSystemChange]>
}
