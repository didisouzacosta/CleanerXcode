//
//  SimulatorSnapshot.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// What a measurement needs to know about the simulators before reading the disk.
struct SimulatorSnapshot: Equatable {
    var hasBootedDevices = false
    var areToolsAvailable = true
    /// A listing failure other than missing tools.
    var listingFailure: CleanupError?
    var unavailableBytes: Int64 = 0
    /// Every UDID of every set; `nil` when any set could not be listed.
    var knownUDIDs: Set<String>?
}

struct SimulatorSnapshotReader {

    // MARK: - Public Properties

    let simulators: any SimulatorManaging
    let locations: CleanupLocations

    // MARK: - Public Methods

    /// `nil` when cancelled. The default set is listed once and its UDIDs reused for the orphan
    /// folders, so only the auxiliary sets are listed again.
    func read() async -> SimulatorSnapshot? {
        var snapshot = SimulatorSnapshot()

        do {
            let devices = try await simulators.listDevices(in: .default)
            snapshot.hasBootedDevices = devices.contains { $0.state == .booted }
            snapshot.unavailableBytes = devices.filter { !$0.isAvailable }.reduce(0) { $0 + $1.sizeBytes }

            let auxiliaryUDIDs = try? await OrphanSimulatorTempFinder.knownUDIDs(
                from: simulators,
                in: Array(DeviceSet.all(in: locations).dropFirst())
            )
            snapshot.knownUDIDs = auxiliaryUDIDs.map { $0.union(devices.map(\.udid)) }
        } catch {
            let cleanupError = CleanupError(error)

            guard cleanupError != .cancelled else { return nil }

            if cleanupError == .toolUnavailable {
                snapshot.areToolsAvailable = false
            } else {
                snapshot.listingFailure = cleanupError
            }
        }

        return Task.isCancelled ? nil : snapshot
    }

}
