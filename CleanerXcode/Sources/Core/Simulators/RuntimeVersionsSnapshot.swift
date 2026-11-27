//
//  RuntimeVersionsSnapshot.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// What the "Download runtimes" sheet knows to offer versions (C35): the selected Xcode's simulator
/// SDK versions and the runtimes of Apple's catalog for this Mac.
nonisolated struct RuntimeVersionsSnapshot: Sendable, Hashable {

    // MARK: - Public Properties

    /// Empty when `xcodebuild -showsdks` failed.
    let sdkVersions: [RuntimePlatform: RuntimeBuildVersion]
    /// `nil` when the catalog is unavailable: no network nor usable cache, or unreadable (R6).
    let catalog: [RuntimeCatalogEntry]?

    /// With the catalog and at least one SDK version, earlier versions can be offered.
    var isComplete: Bool {
        catalog != nil && !sdkVersions.isEmpty
    }

}
