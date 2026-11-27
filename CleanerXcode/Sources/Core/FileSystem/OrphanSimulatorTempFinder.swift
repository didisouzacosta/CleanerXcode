//
//  OrphanSimulatorTempFinder.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// `/private/var/tmp/com.apple.CoreSimulator.SimDevice.<UDID>` folders whose simulator no longer
/// exists in any device set (F19).
nonisolated struct OrphanSimulatorTempFinder: Sendable {

    // MARK: - Public Properties

    static let namePrefix = "com.apple.CoreSimulator.SimDevice."

    /// Uppercased, because UDIDs are compared without case.
    let knownUDIDs: Set<String>

    // MARK: - Initializers

    init(knownUDIDs: Set<String>) {
        self.knownUDIDs = Set(knownUDIDs.map { $0.uppercased() })
    }

    // MARK: - Public Methods

    /// Every set must be listed: without the full list nothing can be called an orphan, so any
    /// failure is thrown.
    static func knownUDIDs(from simulators: any SimulatorManaging, in sets: [DeviceSet]) async throws -> Set<String> {
        var udids: Set<String> = []

        for set in sets {
            try await udids.formUnion(simulators.listDevices(in: set).map(\.udid))
        }

        return udids
    }

    func isOrphan(_ url: URL) -> Bool {
        let name = url.lastPathComponent

        guard
            name.hasPrefix(Self.namePrefix),
            let udid = UUID(uuidString: String(name.dropFirst(Self.namePrefix.count)))
        else {
            return false
        }

        return !knownUDIDs.contains(udid.uuidString)
    }

}
