//
//  InertCleanupServices.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

extension CleanupLocations {

    // MARK: - Public Properties

    /// A folder that never exists: every root of the inert catalog is missing, so measuring it
    /// reads nothing on this Mac.
    static let inertBasePath = "/var/empty/CleanerXcode-inert"

    static let inert = CleanupLocations(
        home: URL(filePath: "\(inertBasePath)/home", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "\(inertBasePath)/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "\(inertBasePath)/tmp", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "\(inertBasePath)/var-tmp", directoryHint: .isDirectory)
    )

}

/// Used by the test host and previews, with `CleanupLocations.inert`: the window can open and
/// measure, but nothing reads this Mac's folders, runs `simctl` or removes anything.
nonisolated struct InertDiskUsageScanner: DiskUsageScanning {

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupTarget) throws -> Int64 {
        0
    }

}

/// Behaves as if the Xcode tools were missing, so every simulator category is unavailable.
nonisolated struct InertSimulatorManager: SimulatorManaging {

    // MARK: - Public Methods

    func listDevices(in set: DeviceSet) throws -> [SimulatorDevice] {
        throw CleanupError.toolUnavailable
    }

    func listRuntimes() throws -> [SimulatorRuntime] {
        throw CleanupError.toolUnavailable
    }

    func shutdownAll(in set: DeviceSet) throws {
        throw CleanupError.toolUnavailable
    }

    func delete(_ devices: [SimulatorDevice], in set: DeviceSet) throws {
        throw CleanupError.toolUnavailable
    }

    func deleteUnavailable() throws {
        throw CleanupError.toolUnavailable
    }

    func eraseAll() throws {
        throw CleanupError.toolUnavailable
    }

    func deleteAllDevices(in set: DeviceSet) throws {
        throw CleanupError.toolUnavailable
    }

    func deleteRuntime(identifier: String) throws {
        throw CleanupError.toolUnavailable
    }

    func restartService() throws {
        throw CleanupError.toolUnavailable
    }

}

/// Runs nothing and reports an empty run.
struct InertCleanupExecutor: CleanupExecuting {

    // MARK: - Public Methods

    func execute(_ plan: CleanupPlan, onEvent: @escaping (CleanupEvent) -> Void) -> CleanupReport {
        CleanupReport(results: [])
    }

}

/// Nothing is open, and nothing is ever quit.
struct InertRunningApplications: RunningApplicationsProviding {

    // MARK: - Public Properties

    var isXcodeRunning: Bool {
        false
    }

    var isSimulatorRunning: Bool {
        false
    }

    // MARK: - Public Methods

    func terminateSimulator() -> Bool {
        false
    }

}
