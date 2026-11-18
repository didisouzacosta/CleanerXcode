//
//  SimulatorManaging.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated protocol SimulatorManaging: Sendable {
    func listDevices(in set: DeviceSet) async throws -> [SimulatorDevice]
    func listRuntimes() async throws -> [SimulatorRuntime]
    func shutdownAll(in set: DeviceSet) async throws
    /// Shuts the booted devices down first, then deletes all of them.
    func delete(_ devices: [SimulatorDevice], in set: DeviceSet) async throws
    func deleteUnavailable() async throws
    func eraseAll() async throws
    func deleteAllDevices(in set: DeviceSet) async throws
    func deleteRuntime(identifier: String) async throws
    func restartService() async throws
}
