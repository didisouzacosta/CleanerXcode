//
//  CategoryPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The title, the one-line explanation and the SF Symbol of each category row (Figma, page 01).
struct CategoryPresentation {

    // MARK: - Public Properties

    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String

    // MARK: - Initializers

    init(_ id: CleanupCategoryID) {
        self = Self.xcode(id) ?? Self.simulators(id) ?? Self.others(id)
    }

    private init(_ title: LocalizedStringResource, _ subtitle: LocalizedStringResource, _ systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    // MARK: - Private Methods

    private static func xcode(_ id: CleanupCategoryID) -> CategoryPresentation? {
        switch id {
        case .removeDerivedData:
            .init("DerivedData", "Builds and indexes; Xcode rebuilds them", "square.3.layers.3d")

        case .removeCaches:
            .init("Xcode and package manager caches", "Xcode, xcodebuild, CocoaPods and Carthage", "shippingbox")

        case .clearDeviceSupport:
            .init(
                "Device Support",
                "iOS, watchOS, tvOS, visionOS and macOS · copied again when a device connects",
                "iphone"
            )

        case .removeSwiftPMCache:
            .init("SwiftPM cache", "Packages downloaded again on the next build", "shippingbox")

        case .removeXcodeProducts:
            .init("Products", "Build products exported by Xcode", "shippingbox")

        default:
            nil
        }
    }

    private static func simulators(_ id: CleanupCategoryID) -> CategoryPresentation? {
        switch id {
        case .clearOrphanSimulatorTemp:
            .init("Orphan simulator temporary files", "Folders with no matching simulator", "clock.arrow.circlepath")

        case .clearSimulatorCaches:
            .init(
                "CoreSimulator caches and logs",
                "Restarts the simulator service without restarting the Mac",
                "shippingbox"
            )

        case .clearAuxiliaryDeviceSets:
            .init("Preview and test simulators", "SwiftUI Previews, XCTest and Playgrounds", "ipad.and.iphone")

        case .removeOldSimulators:
            .init("Unavailable simulators", "From runtimes that no longer exist", "ipad.and.iphone")

        case .clearSimulatorData:
            .init(
                "Erase the content of every simulator",
                "Keeps the simulators; removes apps and data",
                "ipad.and.iphone"
            )

        default:
            nil
        }
    }

    private static func others(_ id: CleanupCategoryID) -> CategoryPresentation {
        switch id {
        case .clearTemporaryFiles:
            .init(
                "Temporary folder",
                "Old files from AI tools and terminals · $TMPDIR and /tmp",
                "clock.arrow.circlepath"
            )

        case .removeArchives:
            .init("Archives", "Goes to the Trash · dSYMs to symbolicate and resubmit", "archivebox")

        case .removeXcodeUserData:
            .init(
                "Xcode user data",
                "Themes, shortcuts, snippets and breakpoints · goes to the Trash",
                "person.crop.square"
            )

        case .removeProvisioningProfiles:
            .init(
                "Provisioning Profiles",
                "Xcode downloads them again when signing · goes to the Trash",
                "doc.badge.gearshape"
            )

        default:
            .init("Reset Xcode preferences", "DerivedData location, behaviors and windows", "slider.horizontal.3")
        }
    }

}
