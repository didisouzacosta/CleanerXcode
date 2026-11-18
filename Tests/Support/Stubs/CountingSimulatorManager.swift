//
//  CountingSimulatorManager.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Lists no simulators and counts every listing, so a test can tell a measurement that runs
/// `simctl` from one that does not. Every change is a no-op.
nonisolated final class CountingSimulatorManager: SimulatorManaging, Sendable {

    // MARK: - Public Properties

    var listCount: Int {
        calls.withLock { $0 }
    }

    // MARK: - Private Properties

    private let calls = Mutex(0)

    // MARK: - Public Methods

    func listDevices(in set: DeviceSet) throws -> [SimulatorDevice] {
        calls.withLock { $0 += 1 }
        return []
    }

    func listRuntimes() throws -> [SimulatorRuntime] {
        []
    }

    func shutdownAll(in set: DeviceSet) throws {}

    func delete(_ devices: [SimulatorDevice], in set: DeviceSet) throws {}

    func deleteUnavailable() throws {}

    func eraseAll() throws {}

    func deleteAllDevices(in set: DeviceSet) throws {}

    func deleteRuntime(identifier: String) throws {}

    func restartService() throws {}

}
