//
//  CleanupOperation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated enum CleanupOperation: Sendable, Hashable {

    // MARK: - Cases

    /// Removes the direct children of each target root, keeping the root itself.
    case removeContents(RemovalMode)
    /// Removes `com.apple.CoreSimulator.SimDevice.<UDID>` folders without a matching simulator.
    case removeOrphanSimulatorTemp
    /// Removes temporary items that pass the `TemporaryItemsPolicy`.
    case removeTemporaryItems
    /// `simctl shutdown all` followed by `simctl erase all`.
    case eraseAllSimulators
    /// `simctl delete unavailable`.
    case deleteUnavailableSimulators
    /// `simctl --set <root> shutdown all` and `delete all` for each target root, then the leftovers.
    case clearDeviceSets
    /// Removes a whole preferences domain.
    case resetPreferences(domain: String)
}
