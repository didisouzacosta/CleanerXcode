//
//  DuplicateSimulatorDetector.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Devices of the same type on the same runtime. The most recently used one is kept.
nonisolated struct DuplicateGroup: Sendable, Hashable {
    let keep: SimulatorDevice
    let duplicates: [SimulatorDevice]
}

/// Only suggests: the interface selects the duplicates and the user confirms the removal (R8).
nonisolated enum DuplicateSimulatorDetector {

    // MARK: - Public Methods

    /// Groups ordered by device type and runtime. Inside a group the most recent `lastUsedAt`
    /// comes first, a device never used counts as the oldest, and ties fall back to the UDID.
    /// Devices without a type or runtime are never grouped: they may be different devices.
    static func groups(in devices: [SimulatorDevice]) -> [DuplicateGroup] {
        let comparable = devices.filter { !$0.deviceTypeIdentifier.isEmpty && !$0.runtimeIdentifier.isEmpty }

        return Dictionary(grouping: comparable) { GroupKey(
            deviceType: $0.deviceTypeIdentifier,
            runtime: $0.runtimeIdentifier
        ) }
        .sorted { ($0.key.deviceType, $0.key.runtime) < ($1.key.deviceType, $1.key.runtime) }
        .compactMap { _, members in
            let ordered = members.sorted(by: isMoreRecent)

            guard let keep = ordered.first, ordered.count > 1 else { return nil }

            return DuplicateGroup(keep: keep, duplicates: Array(ordered.dropFirst()))
        }
    }

    static func suggestedForRemoval(in devices: [SimulatorDevice]) -> [SimulatorDevice] {
        groups(in: devices).flatMap(\.duplicates)
    }

    // MARK: - Private Methods

    private static func isMoreRecent(_ lhs: SimulatorDevice, than rhs: SimulatorDevice) -> Bool {
        switch (lhs.lastUsedAt, rhs.lastUsedAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate: lhsDate > rhsDate
        case (.some, nil): true
        case (nil, .some): false
        default: lhs.udid < rhs.udid
        }
    }

    // MARK: - Nested Types

    private struct GroupKey: Hashable {
        let deviceType: String
        let runtime: String
    }

}
