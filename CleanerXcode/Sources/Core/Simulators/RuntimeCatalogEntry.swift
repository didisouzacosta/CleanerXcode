//
//  RuntimeCatalogEntry.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// A simulator runtime that Apple's catalog offers for download on this Mac (C35): a final
/// release, with the size of the variant for this Mac's architecture.
nonisolated struct RuntimeCatalogEntry: Sendable, Hashable {

    // MARK: - Public Properties

    let platform: RuntimePlatform
    let version: RuntimeBuildVersion
    /// Such as "23F77"; `-buildVersion` takes the version, so it is only informative.
    let build: String
    let sizeBytes: Int64

}
