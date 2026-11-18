//
//  CleanupCategoryID.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Stable category identifiers. The raw values are the preference keys, so the seven legacy
/// categories keep the keys saved by earlier versions. The order is the catalog order.
nonisolated enum CleanupCategoryID: String, CaseIterable, Sendable, Hashable {

    // MARK: - Cases

    case removeDerivedData = "remove-derived-data"
    case removeCaches = "remove-caches"
    case removeArchives = "remove-archives"
    case clearDeviceSupport = "clear-device-support"
    case clearSimulatorData = "clear-simulator-data"
    case removeOldSimulators = "remove-old-simulators"
    case resetXcodePreferences = "reset-xcode-preferences"
    case clearAuxiliaryDeviceSets = "clear-auxiliary-device-sets"
    case clearSimulatorCaches = "clear-simulator-caches"
    case clearOrphanSimulatorTemp = "clear-orphan-simulator-temp"
    case clearTemporaryFiles = "clear-temporary-files"
    case removeSwiftPMCache = "remove-swiftpm-cache"
    case removeXcodeProducts = "remove-xcode-products"
    case removeXcodeUserData = "remove-xcode-user-data"
    case removeProvisioningProfiles = "remove-provisioning-profiles"
}
