//
//  FreeUpSpace.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 18/03/25.
//

struct FreeUpSpace: Decodable {
    
    let derivedData: Double
    let archives: Double
    let simulatorData: Double
    let xcodeCache: Double
    let carthageCache: Double
    let deviceSupportIOS: Double
    let deviceSupportWatchOS: Double
    let deviceSupportTvOS: Double
    
    enum CodingKeys: String, CodingKey {
        case derivedData = "derived_data"
        case archives = "archives"
        case simulatorData = "simulator_data"
        case xcodeCache = "xcode_cache"
        case carthageCache = "carthage_cache"
        case deviceSupportIOS = "device_support_ios"
        case deviceSupportWatchOS = "device_support_watchos"
        case deviceSupportTvOS = "device_support_tvos"
    }
    
    var deviceSupportSize: Double {
        [
            deviceSupportIOS,
            deviceSupportWatchOS,
            deviceSupportTvOS
        ].reduce(0, +)
    }
    
    var totalSize: Double {
        [
            derivedData,
            archives,
            simulatorData,
            xcodeCache,
            carthageCache,
            deviceSupportSize
        ].reduce(0, +)
    }
    
}
