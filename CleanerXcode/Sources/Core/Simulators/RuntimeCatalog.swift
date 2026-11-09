//
//  RuntimeCatalog.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// The runtimes Apple's catalog offers on this Mac, by platform (in the order of
/// `RuntimePlatform.allCases`) and newest version first, and how long the catalog asks to be kept
/// before it is read again (C35, R2, R7).
nonisolated struct RuntimeCatalog: Sendable, Hashable {

    // MARK: - Public Properties

    let entries: [RuntimeCatalogEntry]
    let refreshInterval: Duration

}
