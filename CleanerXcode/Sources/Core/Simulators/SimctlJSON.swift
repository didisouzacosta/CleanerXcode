//
//  SimctlJSON.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The parts of the `simctl` JSON the app reads. Every field the app does not need to work is
/// optional, so a new or missing field never breaks the list.
nonisolated enum SimctlJSON {

    // MARK: - Public Methods

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Nested Types

    /// `simctl list --json devices`.
    struct DeviceList: Decodable {
        let devices: [String: [Device]]
    }

    struct Device: Decodable {
        let udid: String
        let name: String
        let deviceTypeIdentifier: String?
        let state: String?
        let isAvailable: Bool?
        let lastUsedAt: Date?
        let dataPath: String?
        let dataPathSize: Int64?
        let logPathSize: Int64?
    }

    /// An entry of `simctl runtime list --json`, keyed by its identifier.
    struct Runtime: Decodable {

        // MARK: - Public Properties

        let identifier: String
        let runtimeIdentifier: String?
        let version: String?
        let build: String?
        let platformIdentifier: String?
        let sizeBytes: Int64?
        let lastUsedAt: Date?
        let deletable: Bool?
        let state: String?
        let kind: String?

    }

}
