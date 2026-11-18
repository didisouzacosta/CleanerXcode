//
//  FileSystemChangeWatcherFake.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Stands in for FSEvents: it signals each request and each end of a stream, and the test sends
/// the batches, so nothing watches the disk.
nonisolated final class FileSystemChangeWatcherFake: FileSystemChangeWatching, Sendable {

    // MARK: - Public Properties

    /// The directories of each request, as it arrives.
    let requests = AsyncStream.makeStream(of: [String].self)
    /// One signal each time a stream ends.
    let terminations = AsyncStream.makeStream(of: Void.self)

    var requestedDirectories: [[String]] {
        state.withLock { $0.requested }
    }

    // MARK: - Private Properties

    private let state = Mutex<(
        requested: [[String]],
        continuation: AsyncStream<[FileSystemChange]>.Continuation?
    )>(([], nil))

    // MARK: - Public Methods

    func changes(under directories: [String], latency: Duration) -> AsyncStream<[FileSystemChange]> {
        let (changes, continuation) = AsyncStream.makeStream(of: [FileSystemChange].self)
        let terminations = terminations.continuation

        continuation.onTermination = { _ in
            terminations.yield()
        }

        state.withLock { state in
            state.requested.append(directories)
            state.continuation = continuation
        }

        requests.continuation.yield(directories)

        return changes
    }

    /// Sends a batch to the latest stream.
    func send(_ batch: [FileSystemChange]) {
        state.withLock { $0.continuation }?.yield(batch)
    }

}
