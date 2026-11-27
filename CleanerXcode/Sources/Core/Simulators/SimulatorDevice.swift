//
//  SimulatorDevice.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated struct SimulatorDevice: Identifiable, Sendable, Hashable {

    // MARK: - Public Properties

    let udid: String
    let name: String
    let deviceTypeIdentifier: String
    let runtimeIdentifier: String
    let state: State
    let isAvailable: Bool
    let lastUsedAt: Date?
    /// `dataPathSize + logPathSize`, or the size of the device folder when `simctl` omits them.
    let sizeBytes: Int64

    var id: String {
        udid
    }

    // MARK: - Nested Types

    enum State: Sendable, Hashable {

        // MARK: - Cases

        case booted
        case shutdown
        case other(String)

        // MARK: - Initializers

        init(simctlValue: String) {
            self = switch simctlValue {
            case "Booted": .booted
            case "Shutdown": .shutdown
            default: .other(simctlValue)
            }
        }

    }

}
