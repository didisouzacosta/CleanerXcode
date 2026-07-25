//
//  UsedSpace.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 18/03/25.
//

struct UsedSpace: Decodable, Equatable, Sendable {

    // MARK: - Public Properties

    let derivedData: Int64
    let archives: Int64
    let simulatorData: Int64
    let xcodeCache: Int64
    let carthageCache: Int64
    let cocoaPodsCache: Int64
    let deviceSupportIOS: Int64
    let deviceSupportWatchOS: Int64
    let deviceSupportTvOS: Int64

    var cache: Int64 {
        xcodeCache + carthageCache + cocoaPodsCache
    }

    var deviceSupport: Int64 {
        deviceSupportIOS + deviceSupportWatchOS + deviceSupportTvOS
    }

    var totalSize: Int64 {
        derivedData + archives + simulatorData + cache + deviceSupport
    }

    // MARK: - Private Properties

    private enum CodingKeys: String, CodingKey {
        case derivedData = "derived_data"
        case archives
        case simulatorData = "simulator_data"
        case xcodeCache = "xcode_cache"
        case carthageCache = "carthage_cache"
        case cocoaPodsCache = "cocoapods_cache"
        case deviceSupportIOS = "device_support_ios"
        case deviceSupportWatchOS = "device_support_watchos"
        case deviceSupportTvOS = "device_support_tvos"
    }

    // MARK: - Initializer

    init(
        _ derivedData: Int64 = 0,
        archives: Int64 = 0,
        simulatorData: Int64 = 0,
        xcodeCache: Int64 = 0,
        carthageCache: Int64 = 0,
        cocoaPodsCache: Int64 = 0,
        deviceSupportIOS: Int64 = 0,
        deviceSupportWatchOS: Int64 = 0,
        deviceSupportTvOS: Int64 = 0
    ) {
        self.derivedData = derivedData
        self.archives = archives
        self.simulatorData = simulatorData
        self.xcodeCache = xcodeCache
        self.carthageCache = carthageCache
        self.cocoaPodsCache = cocoaPodsCache
        self.deviceSupportIOS = deviceSupportIOS
        self.deviceSupportWatchOS = deviceSupportWatchOS
        self.deviceSupportTvOS = deviceSupportTvOS
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        derivedData = try Self.decodedBytes(for: .derivedData, from: container)
        archives = try Self.decodedBytes(for: .archives, from: container)
        simulatorData = try Self.decodedBytes(for: .simulatorData, from: container)
        xcodeCache = try Self.decodedBytes(for: .xcodeCache, from: container)
        carthageCache = try Self.decodedBytes(for: .carthageCache, from: container)
        cocoaPodsCache = try Self.decodedBytes(for: .cocoaPodsCache, from: container)
        deviceSupportIOS = try Self.decodedBytes(for: .deviceSupportIOS, from: container)
        deviceSupportWatchOS = try Self.decodedBytes(for: .deviceSupportWatchOS, from: container)
        deviceSupportTvOS = try Self.decodedBytes(for: .deviceSupportTvOS, from: container)
    }

    // MARK: - Private Methods

    private static func decodedBytes(for key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>) throws -> Int64 {
        let kibibytes = try container.decodeIfPresent(Int64.self, forKey: key) ?? 0
        return kibibytes * 1_024
    }
}
