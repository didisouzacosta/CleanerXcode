//
//  RuntimeVersionOptions.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// The versions a platform of the "Download runtimes" sheet offers (C35, R3, R11). The first is
/// always the selected Xcode's version, exactly the download of the C30; then the catalog's versions
/// strictly older than Xcode's SDK, newest first, without the ones already installed. Nothing newer
/// than Xcode is offered, and without the SDK version nothing earlier is.
enum RuntimeVersionOptions {

    // MARK: - Public Methods

    static func options(
        for platform: RuntimePlatform,
        snapshot: RuntimeVersionsSnapshot?,
        installed: [SimulatorRuntime]
    ) -> [RuntimeVersionOption] {
        guard let sdkVersion = snapshot?.sdkVersions[platform] else {
            return [RuntimeVersionOption(version: nil, title: String(localized: "Xcode version"), sizeBytes: nil)]
        }

        let entries = snapshot?.catalog?.filter { $0.platform == platform } ?? []
        let xcodeEntry = entries
            .first { RuntimeBuildVersion.compareNumerically($0.version, sdkVersion) == .orderedSame }
        let xcodeOption = RuntimeVersionOption(
            version: nil,
            title: String(localized: "\(sdkVersion.rawValue) (Xcode)"),
            sizeBytes: xcodeEntry?.sizeBytes
        )
        let installedVersions = installed.filter(platform.matches).compactMap { RuntimeBuildVersion($0.version) }

        var earlier: [RuntimeCatalogEntry] = []

        for entry in entries
            where RuntimeBuildVersion.compareNumerically(entry.version, sdkVersion) == .orderedAscending
        {
            let isListed = (earlier.map(\.version) + installedVersions).contains {
                RuntimeBuildVersion.compareNumerically($0, entry.version) == .orderedSame
            }

            if !isListed {
                earlier.append(entry)
            }
        }

        let sorted = earlier.sorted {
            RuntimeBuildVersion.compareNumerically($0.version, $1.version) == .orderedDescending
        }

        return [xcodeOption] + sorted.map {
            RuntimeVersionOption(version: $0.version, title: $0.version.rawValue, sizeBytes: $0.sizeBytes)
        }
    }

}
