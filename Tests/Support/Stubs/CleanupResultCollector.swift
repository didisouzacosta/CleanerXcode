//
//  CleanupResultCollector.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Synchronization
@testable import CleanerXcode

/// Collects the results a remover hands to its `@Sendable` callback.
nonisolated final class CleanupResultCollector: Sendable {

    // MARK: - Public Properties

    var results: [CleanupItemResult] {
        state.withLock { $0 }
    }

    // MARK: - Private Properties

    private let state = Mutex<[CleanupItemResult]>([])

    // MARK: - Public Methods

    func append(_ result: CleanupItemResult) {
        state.withLock { $0.append(result) }
    }

}
