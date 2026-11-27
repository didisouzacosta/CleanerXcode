//
//  DeviceSet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The default simulator set or another one, such as the XCTest or Previews sets.
nonisolated enum DeviceSet: Sendable, Hashable {

    // MARK: - Cases

    case `default`
    case custom(URL)

    // MARK: - Public Properties

    /// The sets Xcode keeps besides the default one, relative to the home folder: the XCTest
    /// clones, the SwiftUI Previews and Interface Builder devices, and the Playgrounds devices.
    static let auxiliarySetPaths = [
        "Library/Developer/XCTestDevices",
        "Library/Developer/Xcode/UserData/Previews/Simulator Devices",
        "Library/Developer/Xcode/UserData/IB Support/Simulator Devices",
        "Library/Developer/XCPGDevices",
    ]

    /// Goes right after `simctl`, before the subcommand.
    var arguments: [String] {
        switch self {
        case .default: []
        case let .custom(url): ["--set", url.path(percentEncoded: false)]
        }
    }

    // MARK: - Public Methods

    /// "Every set" for the orphan simulator folders (F19): the default set plus the auxiliary
    /// sets whose folders exist, because `simctl` fails on a missing set path.
    static func all(in locations: CleanupLocations) -> [DeviceSet] {
        let auxiliary = auxiliarySetPaths
            .map { locations.home.appending(path: $0, directoryHint: .isDirectory) }
            .filter { FileManager().fileExists(atPath: $0.path(percentEncoded: false)) }
            .map(DeviceSet.custom)

        return [.default] + auxiliary
    }

}
