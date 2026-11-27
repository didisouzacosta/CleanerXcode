//
//  DemoSystemFakes.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    import Foundation

    /// The demo's simulators for the cleanup pages: one shut down and two unavailable ones, the
    /// 1.6 GB of "Unavailable simulators" in the storyboard. Nothing ever runs `simctl`.
    nonisolated struct DemoSimulatorManager: SimulatorManaging {

        // MARK: - Public Properties

        static let devices: [SimulatorDevice] = [
            device("iPhone 17 Pro", udid: "DEMO-0001", isAvailable: true, sizeBytes: 2_400_000_000),
            device("iPhone 15", udid: "DEMO-0002", isAvailable: false, sizeBytes: 1_000_000_000),
            device("iPad Air 11-inch", udid: "DEMO-0003", isAvailable: false, sizeBytes: 600_000_000),
        ]

        static var unavailableBytes: Int64 {
            devices.filter { !$0.isAvailable }.reduce(0) { $0 + $1.sizeBytes }
        }

        // MARK: - Private Static Methods

        private static func device(
            _ name: String,
            udid: String,
            isAvailable: Bool,
            sizeBytes: Int64
        ) -> SimulatorDevice {
            SimulatorDevice(
                udid: udid,
                name: name,
                deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.Demo",
                runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-2",
                state: .shutdown,
                isAvailable: isAvailable,
                lastUsedAt: nil,
                sizeBytes: sizeBytes
            )
        }

        // MARK: - Public Methods

        func listDevices(in set: DeviceSet) -> [SimulatorDevice] {
            set == .default ? Self.devices : []
        }

        func listRuntimes() -> [SimulatorRuntime] {
            []
        }

        func shutdownAll(in set: DeviceSet) {}

        func delete(_ devices: [SimulatorDevice], in set: DeviceSet) {}

        func deleteUnavailable() {}

        func eraseAll() {}

        func deleteAllDevices(in set: DeviceSet) {}

        func deleteRuntime(identifier: String) {}

        func restartService() {}

    }

    /// Xcode and Simulator are closed during the demo, so no warning covers the window.
    struct DemoRunningApplications: RunningApplicationsProviding {

        // MARK: - Public Properties

        let isXcodeRunning = false
        let isSimulatorRunning = false

        // MARK: - Public Methods

        func terminateSimulator() -> Bool {
            true
        }

    }
#endif
