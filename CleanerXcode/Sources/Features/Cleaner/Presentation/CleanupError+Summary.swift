//
//  CleanupError+Summary.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

extension CleanupError {

    // MARK: - Public Properties

    /// A short reason for the interface; never sent to analytics or error reports.
    var summary: LocalizedStringResource {
        switch self {
        case .permissionDenied: "No permission"
        case .inUse: "In use by another process (EBUSY)"
        case .notFound: "Not found"
        case .toolUnavailable: "The Xcode tools are unavailable"
        case let .commandFailed(exitCode, _): "The command failed (code \(Int(exitCode)))"
        case .timedOut: "Timed out"
        case .cancelled: "Cancelled"
        case .blockedByRunningApp: "Blocked by an open app"
        case .unsafePath: "Location not allowed"
        case .unsupportedRoot: "Unsupported location"
        case .unknown: "Unknown error"
        }
    }

}
