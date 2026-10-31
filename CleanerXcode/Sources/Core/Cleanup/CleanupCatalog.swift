//
//  CleanupCatalog.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The single source of truth for what the app cleans (plan, table 5.5). Every root is built from
/// `CleanupLocations` and lives inside the home folder or one of the temporary folders.
nonisolated struct CleanupCatalog: Sendable {

    // MARK: - Public Properties

    let locations: CleanupLocations
    let categories: [CleanupCategory]

    // MARK: - Initializers

    init(locations: CleanupLocations) {
        self.locations = locations
        self.categories = Self.makeCategories(in: locations)
    }

    // MARK: - Private Static Methods

    private static func makeCategories(in locations: CleanupLocations) -> [CleanupCategory] {
        let paths = Paths(locations: locations)

        return xcodeCategories(paths) + simulatorCategories(paths) + temporaryAndUserDataCategories(paths)
    }

    /// DerivedData, caches, Archives and Device Support.
    private static func xcodeCategories(_ paths: Paths) -> [CleanupCategory] {
        [
            CleanupCategory(
                id: .removeDerivedData,
                targets: [paths.target(paths.xcode, "DerivedData")],
                operation: .removeContents(.delete),
                risk: .safe,
                isEnabledByDefault: true
            ),
            CleanupCategory(
                id: .removeCaches,
                targets: [
                    paths.target(paths.caches, "com.apple.dt.Xcode"),
                    paths.target(paths.caches, "com.apple.dt.xcodebuild"),
                    paths.target(paths.caches, "org.carthage.CarthageKit"),
                    paths.target(paths.caches, "CocoaPods"),
                ],
                operation: .removeContents(.delete),
                risk: .safe,
                isEnabledByDefault: true
            ),
            CleanupCategory(
                id: .removeArchives,
                targets: [paths.target(paths.xcode, "Archives")],
                operation: .removeContents(.trash),
                risk: .dangerous,
                isEnabledByDefault: false
            ),
            CleanupCategory(
                id: .clearDeviceSupport,
                targets: ["iOS", "watchOS", "tvOS", "visionOS", "macOS"].map { paths.target(
                    paths.xcode,
                    "\($0) DeviceSupport"
                ) },
                operation: .removeContents(.delete),
                risk: .attention,
                isEnabledByDefault: false
            ),
        ]
    }

    /// Simulators, Xcode preferences and the CoreSimulator leftovers.
    private static func simulatorCategories(_ paths: Paths) -> [CleanupCategory] {
        [
            CleanupCategory(
                id: .clearSimulatorData,
                targets: [paths.target(paths.coreSimulator, "Devices")],
                operation: .eraseAllSimulators,
                risk: .attention,
                isEnabledByDefault: false
            ),
            CleanupCategory(
                id: .removeOldSimulators,
                targets: [],
                operation: .deleteUnavailableSimulators,
                risk: .safe,
                isEnabledByDefault: false
            ),
            CleanupCategory(
                id: .resetXcodePreferences,
                targets: [],
                operation: .resetPreferences(domain: "com.apple.dt.Xcode"),
                risk: .dangerous,
                isEnabledByDefault: false,
                isBlockedWhileXcodeRuns: true
            ),
            CleanupCategory(
                id: .clearAuxiliaryDeviceSets,
                targets: [
                    paths.target(paths.developer, "XCTestDevices"),
                    paths.target(paths.userData, "Previews"),
                    paths.target(paths.userData, "IB Support"),
                    paths.target(paths.developer, "XCPGDevices"),
                ],
                operation: .clearDeviceSets,
                risk: .safe,
                isEnabledByDefault: true
            ),
            CleanupCategory(
                id: .clearSimulatorCaches,
                targets: [
                    paths.target(paths.coreSimulator, "Caches", excluding: ["Personalization"]),
                    paths.target(paths.coreSimulator, "Temp"),
                    paths.target(paths.library, "Logs/CoreSimulator"),
                ],
                operation: .removeContents(.delete),
                risk: .safe,
                isEnabledByDefault: true,
                restartsSimulatorService: true
            ),
        ]
    }

    /// Temporary folders, SwiftPM, Products and the Xcode user data.
    private static func temporaryAndUserDataCategories(_ paths: Paths) -> [CleanupCategory] {
        [
            CleanupCategory(
                id: .clearOrphanSimulatorTemp,
                targets: [CleanupTarget(root: paths.locations.varTemporary)],
                operation: .removeOrphanSimulatorTemp,
                risk: .safe,
                isEnabledByDefault: true
            ),
            CleanupCategory(
                id: .clearTemporaryFiles,
                targets: [
                    CleanupTarget(root: paths.locations.userTemporary),
                    CleanupTarget(root: paths.locations.systemTemporary),
                    CleanupTarget(root: paths.locations.varTemporary),
                ],
                operation: .removeTemporaryItems,
                risk: .attention,
                isEnabledByDefault: false
            ),
            CleanupCategory(
                id: .removeSwiftPMCache,
                targets: [paths.target(paths.caches, "org.swift.swiftpm")],
                operation: .removeContents(.delete),
                risk: .attention,
                isEnabledByDefault: false
            ),
            CleanupCategory(
                id: .removeXcodeProducts,
                targets: [paths.target(paths.xcode, "Products")],
                operation: .removeContents(.delete),
                risk: .attention,
                isEnabledByDefault: false
            ),
            CleanupCategory(
                id: .removeXcodeUserData,
                targets: [CleanupTarget(
                    root: paths.userData,
                    excludedNames: ["Previews", "IB Support", "Provisioning Profiles"]
                )],
                operation: .removeContents(.trash),
                risk: .dangerous,
                isEnabledByDefault: false,
                isBlockedWhileXcodeRuns: true
            ),
            CleanupCategory(
                id: .removeProvisioningProfiles,
                targets: [
                    paths.target(paths.userData, "Provisioning Profiles"),
                    paths.target(paths.library, "MobileDevice/Provisioning Profiles"),
                ],
                operation: .removeContents(.trash),
                risk: .dangerous,
                isEnabledByDefault: false
            ),
        ]
    }

    // MARK: - Public Methods

    func makeSafePathPolicy() -> SafePathPolicy {
        var roots: [URL] = []

        for root in categories.flatMap(\.targets).map(\.root) where !roots.contains(root) {
            roots.append(root)
        }

        return SafePathPolicy(
            roots: roots,
            protectedPaths: [
                URL(filePath: "/", directoryHint: .isDirectory),
                locations.home,
                locations.home.appending(path: "Library", directoryHint: .isDirectory),
            ],
            allowedBases: [
                locations.home.appending(path: "Library", directoryHint: .isDirectory),
                locations.userTemporary,
                locations.systemTemporary,
                locations.varTemporary,
            ]
        )
    }

    // MARK: - Nested Types

    private struct Paths {

        // MARK: - Public Properties

        let locations: CleanupLocations

        var library: URL {
            locations.home.appending(path: "Library", directoryHint: .isDirectory)
        }

        var developer: URL {
            library.appending(path: "Developer", directoryHint: .isDirectory)
        }

        var xcode: URL {
            developer.appending(path: "Xcode", directoryHint: .isDirectory)
        }

        var userData: URL {
            xcode.appending(path: "UserData", directoryHint: .isDirectory)
        }

        var caches: URL {
            library.appending(path: "Caches", directoryHint: .isDirectory)
        }

        var coreSimulator: URL {
            developer.appending(path: "CoreSimulator", directoryHint: .isDirectory)
        }

        // MARK: - Public Methods

        func target(_ base: URL, _ path: String, excluding excludedNames: Set<String> = []) -> CleanupTarget {
            CleanupTarget(root: base.appending(path: path, directoryHint: .isDirectory), excludedNames: excludedNames)
        }

    }

    // MARK: - Subscripts

    subscript(id: CleanupCategoryID) -> CleanupCategory {
        guard let category = categories.first(where: { $0.id == id }) else {
            preconditionFailure("The catalog has no category \(id.rawValue).")
        }

        return category
    }

}
