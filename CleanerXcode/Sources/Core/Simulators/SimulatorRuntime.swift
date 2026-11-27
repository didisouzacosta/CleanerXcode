//
//  SimulatorRuntime.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated struct SimulatorRuntime: Identifiable, Sendable, Hashable {

    // MARK: - Public Properties

    /// The disk image identifier that `simctl runtime delete` takes.
    let identifier: String
    /// The runtime the devices refer to, such as `com.apple.CoreSimulator.SimRuntime.iOS-27-1`.
    let runtimeIdentifier: String
    let version: String
    let build: String
    let platformIdentifier: String
    let sizeBytes: Int64
    let lastUsedAt: Date?
    /// Runtimes bundled with Xcode cannot be deleted and appear disabled.
    let isDeletable: Bool
    /// Such as `Ready`, `Deleting` or `Unusable`.
    let state: String
    /// Such as `Bundled with Xcode` or `Patchable Cryptex Disk Image`.
    let kind: String

    var id: String {
        identifier
    }

}
