//
//  FileOperationsSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Records every delete and move to the Trash. Moves to the Trash never touch the real Trash.
/// Cancelling from `delete` cancels the caller of the remover, which runs in the same task.
nonisolated final class FileOperationsSpy: FileOperating, Sendable {

    // MARK: - Public Properties

    /// Thrown for the items with these names instead of performing the operation.
    let failures: [String: any Error]
    /// Cancels the running task right after the first delete, to stop between items.
    let cancelsAfterFirstDelete: Bool

    var deletedNames: [String] {
        state.withLock { $0.deletedNames }
    }

    var trashedNames: [String] {
        state.withLock { $0.trashedNames }
    }

    var operationsOnMainThread: [Bool] {
        state.withLock { $0.operationsOnMainThread }
    }

    // MARK: - Private Properties

    private let state = Mutex(State())

    // MARK: - Initializers

    init(failures: [String: any Error] = [:], cancelsAfterFirstDelete: Bool = false) {
        self.failures = failures
        self.cancelsAfterFirstDelete = cancelsAfterFirstDelete
    }

    // MARK: - Public Methods

    func delete(_ url: URL) throws {
        let isFirstDelete = state.withLock { state in
            state.operationsOnMainThread.append(Thread.isMainThread)
            state.deletedNames.append(url.lastPathComponent)
            return state.deletedNames.count == 1
        }

        if let failure = failures[url.lastPathComponent] {
            throw failure
        }

        // Deletes for real inside the test folder, so the remaining items can be checked on disk.
        try FileManager().removeItem(at: url)

        if cancelsAfterFirstDelete, isFirstDelete {
            withUnsafeCurrentTask { $0?.cancel() }
        }
    }

    func moveToTrash(_ url: URL) throws {
        state.withLock { state in
            state.operationsOnMainThread.append(Thread.isMainThread)
            state.trashedNames.append(url.lastPathComponent)
        }

        if let failure = failures[url.lastPathComponent] {
            throw failure
        }
    }

    // MARK: - Nested Types

    private struct State {
        var deletedNames: [String] = []
        var trashedNames: [String] = []
        var operationsOnMainThread: [Bool] = []
    }

}
