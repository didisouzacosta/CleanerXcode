//
//  DiskUsageScannerStub.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
@testable import CleanerXcode

/// Answers each root with a fixed size or failure, without touching the file system.
nonisolated struct DiskUsageScannerStub: DiskUsageScanning {

    // MARK: - Public Properties

    var sizes: [URL: Int64] = [:]
    var failures: [URL: CleanupError] = [:]
    /// When set, every call waits until the expected number of calls are in flight at once.
    var barrier: StartBarrier?
    /// When true, every call suspends until its task is cancelled.
    var suspendsUntilCancelled = false

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupTarget) async throws -> Int64 {
        if let barrier {
            await barrier.arriveAndWait()
        }

        if suspendsUntilCancelled {
            try await Task.sleep(for: .seconds(60))
        }

        if let failure = failures[target.root] {
            throw failure
        }

        return sizes[target.root] ?? 0
    }

}

/// Releases every waiter only when `count` callers have arrived, so a sequential caller hangs.
actor StartBarrier {

    // MARK: - Private Properties

    private let count: Int

    private var waiting: [CheckedContinuation<Void, Never>] = []

    // MARK: - Initializers

    init(count: Int) {
        self.count = count
    }

    // MARK: - Public Methods

    func arriveAndWait() async {
        guard waiting.count + 1 < count else {
            waiting.forEach { $0.resume() }
            waiting.removeAll()
            return
        }

        await withCheckedContinuation { waiting.append($0) }
    }

}
