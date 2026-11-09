//
//  RuntimeCatalogError.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// Why the catalog of downloadable runtimes could not be read (C35). Either way the sheet offers only
/// the version that matches Xcode (R6).
nonisolated enum RuntimeCatalogError: Error, Sendable, Equatable {
    /// Not a property list with a list of downloadables.
    case malformed
    /// Not a 2xx answer, or a body larger than the limit.
    case badResponse
}
