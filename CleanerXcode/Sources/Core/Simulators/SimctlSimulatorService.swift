//
//  SimctlSimulatorService.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Simulators and runtimes through `xcrun simctl`. It never removes files under
/// `/Library/Developer/CoreSimulator` (R10): every change goes through `simctl`.
nonisolated struct SimctlSimulatorService: SimulatorManaging {

    // MARK: - Public Properties

    /// The JSON from `simctl` could not be read: unexpected, so it is reported.
    static let unreadableOutput = CleanupError.unknown(domain: "SimctlJSON", code: 1)

    // MARK: - Private Properties

    /// `xcrun` exits with 72 when it cannot find the tool, for example with only the Command Line
    /// Tools selected.
    private static let toolNotFoundExitCode: Int32 = 72
    /// `xcrun`'s own errors, such as a deleted Xcode that is still selected or a missing
    /// `DEVELOPER_DIR` (exit 1). `simctl` never uses this prefix.
    private static let xcrunErrorPrefix = "xcrun: error:"

    private let runner: any ProcessRunning
    private let scanner: any DiskUsageScanning
    private let restarter: any SimulatorServiceRestarting

    // MARK: - Initializers

    init(
        runner: any ProcessRunning = ProcessRunner(),
        scanner: any DiskUsageScanning = FileSystemSizeScanner(),
        restarter: any SimulatorServiceRestarting = CoreSimulatorServiceRestarter()
    ) {
        self.runner = runner
        self.scanner = scanner
        self.restarter = restarter
    }

    // MARK: - Private Static Methods

    private static func decode<Value: Decodable>(_ type: Value.Type, from output: ProcessOutput) throws -> Value {
        do {
            return try SimctlJSON.decode(type, from: output.standardOutput)
        } catch {
            throw unreadableOutput
        }
    }

    // MARK: - Public Methods

    func listDevices(in set: DeviceSet) async throws -> [SimulatorDevice] {
        let output = try await simctl(set, ["list", "--json", "devices"])
        let list = try Self.decode(SimctlJSON.DeviceList.self, from: output)

        var devices: [SimulatorDevice] = []

        for (runtimeIdentifier, entries) in list.devices.sorted(by: { $0.key < $1.key }) {
            for entry in entries {
                let sizeBytes = try await size(of: entry)

                devices.append(SimulatorDevice(
                    udid: entry.udid,
                    name: entry.name,
                    deviceTypeIdentifier: entry.deviceTypeIdentifier ?? "",
                    runtimeIdentifier: runtimeIdentifier,
                    state: SimulatorDevice.State(simctlValue: entry.state ?? ""),
                    isAvailable: entry.isAvailable ?? false,
                    lastUsedAt: entry.lastUsedAt,
                    sizeBytes: sizeBytes
                ))
            }
        }

        return devices
    }

    func listRuntimes() async throws -> [SimulatorRuntime] {
        let output = try await simctl(.default, ["runtime", "list", "--json"])
        let runtimes = try Self.decode([String: SimctlJSON.Runtime].self, from: output)

        return runtimes.values
            .map { runtime in
                SimulatorRuntime(
                    identifier: runtime.identifier,
                    runtimeIdentifier: runtime.runtimeIdentifier ?? "",
                    version: runtime.version ?? "",
                    build: runtime.build ?? "",
                    platformIdentifier: runtime.platformIdentifier ?? "",
                    sizeBytes: runtime.sizeBytes ?? 0,
                    lastUsedAt: runtime.lastUsedAt,
                    isDeletable: runtime.deletable ?? false,
                    state: runtime.state ?? "",
                    kind: runtime.kind ?? ""
                )
            }
            .sorted { ($0.runtimeIdentifier, $0.identifier) < ($1.runtimeIdentifier, $1.identifier) }
    }

    func shutdownAll(in set: DeviceSet) async throws {
        _ = try await simctl(set, ["shutdown", "all"])
    }

    /// `simctl shutdown` takes a single device, so the booted ones are shut down one by one.
    func delete(_ devices: [SimulatorDevice], in set: DeviceSet) async throws {
        guard !devices.isEmpty else { return }

        for device in devices where device.state == .booted {
            _ = try await simctl(set, ["shutdown", device.udid])
        }

        _ = try await simctl(set, ["delete"] + devices.map(\.udid))
    }

    func deleteUnavailable() async throws {
        _ = try await simctl(.default, ["delete", "unavailable"])
    }

    func eraseAll() async throws {
        _ = try await simctl(.default, ["erase", "all"], timeout: ProcessRequest.eraseAllTimeout)
    }

    func deleteAllDevices(in set: DeviceSet) async throws {
        _ = try await simctl(set, ["delete", "all"])
    }

    func deleteRuntime(identifier: String) async throws {
        _ = try await simctl(.default, ["runtime", "delete", identifier], timeout: ProcessRequest.runtimeDeleteTimeout)
    }

    func restartService() throws {
        try restarter.restart()
    }

    // MARK: - Private Methods

    private func simctl(
        _ set: DeviceSet,
        _ arguments: [String],
        timeout: Duration = ProcessRequest.defaultTimeout
    ) async throws -> ProcessOutput {
        do {
            return try await runner.run(.xcrun(["simctl"] + set.arguments + arguments, timeout: timeout))
        } catch let CleanupError.commandFailed(exitCode, summary)
            where exitCode == Self.toolNotFoundExitCode || summary.hasPrefix(Self.xcrunErrorPrefix)
        {
            throw CleanupError.toolUnavailable
        }
    }

    /// Without `dataPathSize` and `logPathSize`, the device folder (the parent of `dataPath`) is
    /// measured instead; a folder that cannot be measured counts 0. A scan may still return after
    /// cancellation, so the result is only used when the task goes on.
    private func size(of device: SimctlJSON.Device) async throws -> Int64 {
        if device.dataPathSize != nil || device.logPathSize != nil {
            return (device.dataPathSize ?? 0) + (device.logPathSize ?? 0)
        }

        guard let dataPath = device.dataPath else { return 0 }

        let folder = URL(filePath: dataPath).deletingLastPathComponent()
        let size: Int64

        do {
            size = try await scanner.allocatedSize(of: CleanupTarget(root: folder))
        } catch {
            guard CleanupError(error) != .cancelled else { throw CancellationError() }

            return 0
        }

        try Task.checkCancellation()

        return size
    }

}
