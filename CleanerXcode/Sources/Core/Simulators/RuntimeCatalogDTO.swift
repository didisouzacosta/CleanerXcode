//
//  RuntimeCatalogDTO.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// The parts of Apple's catalog of downloadable runtimes (`index2.dvtdownloadableindex`, a property
/// list) the app reads (C35). The format is not documented: every field of an entry is optional, a
/// field of an unexpected type drops only that entry, and only a missing list of downloadables makes
/// the whole catalog unreadable (P4).
nonisolated enum RuntimeCatalogDTO {

    // MARK: - Nested Types

    struct Index: Decodable {

        // MARK: - Public Properties

        let downloadables: [LossyElement<Downloadable>]
        /// In seconds; `nil` when missing or not a number.
        let refreshInterval: Double?

        // MARK: - Initializers

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            downloadables = try container.decode([LossyElement<Downloadable>].self, forKey: .downloadables)
            refreshInterval = try? container.decodeIfPresent(Double.self, forKey: .refreshInterval)
        }

        // MARK: - Nested Types

        private enum CodingKeys: String, CodingKey {
            case downloadables
            case refreshInterval
        }

    }

    struct Downloadable: Decodable {

        // MARK: - Public Properties

        let name: String?
        let platform: String?
        let contentType: String?
        let downloadMethod: String?
        let architectures: [String]?
        let fileSize: Int64?
        let simulatorVersion: SimulatorVersion?
        /// Present with any value, even one of an unexpected type: such a runtime is left out.
        let hasHostRequirements: Bool

        // MARK: - Initializers

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            name = try container.decodeIfPresent(String.self, forKey: .name)
            platform = try container.decodeIfPresent(String.self, forKey: .platform)
            contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
            downloadMethod = try container.decodeIfPresent(String.self, forKey: .downloadMethod)
            architectures = try container.decodeIfPresent([String].self, forKey: .architectures)
            fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
            simulatorVersion = try container.decodeIfPresent(SimulatorVersion.self, forKey: .simulatorVersion)
            hasHostRequirements = container.contains(.hostRequirements)
        }

        // MARK: - Nested Types

        private enum CodingKeys: String, CodingKey {
            case name
            case platform
            case contentType
            case downloadMethod
            case architectures
            case fileSize
            case simulatorVersion
            case hostRequirements
        }

    }

    struct SimulatorVersion: Decodable {
        let version: String?
        let buildUpdate: String?
    }

}
