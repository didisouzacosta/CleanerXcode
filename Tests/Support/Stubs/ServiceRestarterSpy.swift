//
//  ServiceRestarterSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Synchronization
@testable import CleanerXcode

/// Counts restarts without ever signaling the real CoreSimulatorService.
nonisolated final class ServiceRestarterSpy: SimulatorServiceRestarting, Sendable {

    // MARK: - Public Properties

    var restartCount: Int {
        state.withLock { $0 }
    }

    // MARK: - Private Properties

    private let state = Mutex(0)

    // MARK: - Public Methods

    func restart() throws {
        state.withLock { $0 += 1 }
    }

}
