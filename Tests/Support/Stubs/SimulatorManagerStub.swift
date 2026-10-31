//
//  SimulatorManagerStub.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
@testable import CleanerXcode

/// Lists fixed UDIDs per set; every change is a no-op, so nothing real is touched.
nonisolated struct SimulatorManagerStub: SimulatorManaging {

    // MARK: - Public Properties

    var devices: [DeviceSet: [String]] = [:]
    var failingSets: [DeviceSet: CleanupError] = [:]

    // MARK: - Public Methods

    func listDevices(in set: DeviceSet) throws -> [SimulatorDevice] {
        if let failure = failingSets[set] {
            throw failure
        }

        return devices[set, default: []].map { udid in
            SimulatorDevice(
                udid: udid,
                name: udid,
                deviceTypeIdentifier: "type",
                runtimeIdentifier: "runtime",
                state: .shutdown,
                isAvailable: true,
                lastUsedAt: nil,
                sizeBytes: 0
            )
        }
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
