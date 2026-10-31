//
//  CleanupCatalogTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CleanupCatalogTests {

    // MARK: - Private Properties

    private let locations = CleanupLocations(
        home: URL(filePath: "/Users/tester", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/ab/cd/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp", directoryHint: .isDirectory)
    )

    private var catalog: CleanupCatalog {
        CleanupCatalog(locations: locations)
    }

    // MARK: - Public Methods

    @Test
    func listsEveryCategoryOnceInTableOrder() {
        #expect(catalog.categories.map(\.id) == CleanupCategoryID.allCases)
        #expect(CleanupCategoryID.allCases.count == 15)
    }

    @Test
    func legacyCategoriesKeepTheirPreferenceKeys() {
        #expect(CleanupCategoryID.removeDerivedData.rawValue == "remove-derived-data")
        #expect(CleanupCategoryID.removeCaches.rawValue == "remove-caches")
        #expect(CleanupCategoryID.removeArchives.rawValue == "remove-archives")
        #expect(CleanupCategoryID.clearDeviceSupport.rawValue == "clear-device-support")
        #expect(CleanupCategoryID.clearSimulatorData.rawValue == "clear-simulator-data")
        #expect(CleanupCategoryID.removeOldSimulators.rawValue == "remove-old-simulators")
        #expect(CleanupCategoryID.resetXcodePreferences.rawValue == "reset-xcode-preferences")
    }

    @Test(arguments: [
        (CleanupCategoryID.removeDerivedData, CleanupOperation.removeContents(.delete), RiskLevel.safe, true),
        (.removeCaches, .removeContents(.delete), .safe, true),
        (.removeArchives, .removeContents(.trash), .dangerous, false),
        (.clearDeviceSupport, .removeContents(.delete), .attention, false),
        (.clearSimulatorData, .eraseAllSimulators, .attention, false),
        (.removeOldSimulators, .deleteUnavailableSimulators, .safe, false),
        (.resetXcodePreferences, .resetPreferences(domain: "com.apple.dt.Xcode"), .dangerous, false),
        (.clearAuxiliaryDeviceSets, .clearDeviceSets, .safe, true),
        (.clearSimulatorCaches, .removeContents(.delete), .safe, true),
        (.clearOrphanSimulatorTemp, .removeOrphanSimulatorTemp, .safe, true),
        (.clearTemporaryFiles, .removeTemporaryItems, .attention, false),
        (.removeSwiftPMCache, .removeContents(.delete), .attention, false),
        (.removeXcodeProducts, .removeContents(.delete), .attention, false),
        (.removeXcodeUserData, .removeContents(.trash), .dangerous, false),
        (.removeProvisioningProfiles, .removeContents(.trash), .dangerous, false),
    ])
    func categoryMatchesTheCatalogTable(
        id: CleanupCategoryID,
        operation: CleanupOperation,
        risk: RiskLevel,
        isEnabledByDefault: Bool
    ) {
        let category = catalog[id]

        #expect(category.operation == operation)
        #expect(category.risk == risk)
        #expect(category.isEnabledByDefault == isEnabledByDefault)
    }

    @Test
    func onlyXcodeOwnedSettingsAreBlockedWhileXcodeRuns() {
        let blocked = catalog.categories.filter(\.isBlockedWhileXcodeRuns).map(\.id)

        #expect(blocked == [.resetXcodePreferences, .removeXcodeUserData])
    }

    @Test
    func onlySimulatorCachesRestartTheSimulatorService() {
        let restarting = catalog.categories.filter(\.restartsSimulatorService).map(\.id)

        #expect(restarting == [.clearSimulatorCaches])
    }

    @Test
    func everyRootLivesInsideHomeOrTheTemporaryFolders() {
        let allowedBases = [locations.home, locations.userTemporary, locations.systemTemporary, locations.varTemporary]

        for target in catalog.categories.flatMap(\.targets) {
            let isInside = allowedBases.contains { base in
                target.root.path().hasPrefix(base.path())
            }

            #expect(isInside, "\(target.root.path()) is outside the allowed bases")
            #expect(target.root.path() != locations.home.path())
            #expect(target.root.path() != locations.home.appending(path: "Library").path())
        }
    }

    @Test
    func derivedDataAndArchivesTargetTheXcodeFolders() {
        #expect(catalog[.removeDerivedData].targets.map { $0.root.path(percentEncoded: false) } == [
            "/Users/tester/Library/Developer/Xcode/DerivedData/",
        ])
        #expect(catalog[.removeArchives].targets.map { $0.root.path(percentEncoded: false) } == [
            "/Users/tester/Library/Developer/Xcode/Archives/",
        ])
    }

    @Test
    func cachesCoverXcodeXcodebuildCarthageAndCocoaPods() {
        #expect(catalog[.removeCaches].targets.map(\.root.lastPathComponent) == [
            "com.apple.dt.Xcode",
            "com.apple.dt.xcodebuild",
            "org.carthage.CarthageKit",
            "CocoaPods",
        ])
    }

    @Test
    func deviceSupportCoversFivePlatforms() {
        #expect(catalog[.clearDeviceSupport].targets.map(\.root.lastPathComponent) == [
            "iOS DeviceSupport",
            "watchOS DeviceSupport",
            "tvOS DeviceSupport",
            "visionOS DeviceSupport",
            "macOS DeviceSupport",
        ])
    }

    @Test
    func simulatorCachesKeepPersonalization() {
        let targets = catalog[.clearSimulatorCaches].targets

        #expect(targets.map { $0.root.path(percentEncoded: false) } == [
            "/Users/tester/Library/Developer/CoreSimulator/Caches/",
            "/Users/tester/Library/Developer/CoreSimulator/Temp/",
            "/Users/tester/Library/Logs/CoreSimulator/",
        ])
        #expect(targets.first?.excludedNames == ["Personalization"])
    }

    @Test
    func auxiliaryDeviceSetsCoverTestsPreviewsInterfaceBuilderAndPlaygrounds() {
        #expect(catalog[.clearAuxiliaryDeviceSets].targets.map { $0.root.path(percentEncoded: false) } == [
            "/Users/tester/Library/Developer/XCTestDevices/",
            "/Users/tester/Library/Developer/Xcode/UserData/Previews/",
            "/Users/tester/Library/Developer/Xcode/UserData/IB Support/",
            "/Users/tester/Library/Developer/XCPGDevices/",
        ])
    }

    @Test
    func temporaryFilesCoverTheThreeTemporaryFolders() {
        #expect(catalog[.clearTemporaryFiles].targets.map(\.root) == [
            locations.userTemporary,
            locations.systemTemporary,
            locations.varTemporary,
        ])
        #expect(catalog[.clearOrphanSimulatorTemp].targets.map(\.root) == [locations.varTemporary])
    }

    @Test
    func userDataLeavesDeviceSetsAndProfilesToTheirOwnCategories() {
        let userData = catalog[.removeXcodeUserData].targets

        #expect(userData
            .map { $0.root.path(percentEncoded: false) } == ["/Users/tester/Library/Developer/Xcode/UserData/"])
        #expect(userData.first?.excludedNames == ["Previews", "IB Support", "Provisioning Profiles"])
        #expect(catalog[.removeProvisioningProfiles].targets.map { $0.root.path(percentEncoded: false) } == [
            "/Users/tester/Library/Developer/Xcode/UserData/Provisioning Profiles/",
            "/Users/tester/Library/MobileDevice/Provisioning Profiles/",
        ])
    }

    @Test
    func simulatorDataMeasuresTheDefaultDeviceSet() {
        #expect(catalog[.clearSimulatorData].targets.map { $0.root.path(percentEncoded: false) } == [
            "/Users/tester/Library/Developer/CoreSimulator/Devices/",
        ])
        #expect(catalog[.removeOldSimulators].targets.isEmpty)
        #expect(catalog[.resetXcodePreferences].targets.isEmpty)
    }

    @Test
    func safePathPolicyKnowsEveryRoot() {
        let policy = catalog.makeSafePathPolicy()

        #expect(Set(policy.roots) == Set(catalog.categories.flatMap(\.targets).map(\.root)))
    }

}
