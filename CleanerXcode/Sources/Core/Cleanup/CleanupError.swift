//
//  CleanupError.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Per-item failure. It keeps no path or message from the original error, only enumerated values,
/// so it is safe to aggregate into analytics and error reports.
nonisolated enum CleanupError: Error, Sendable, Hashable {

    // MARK: - Cases

    case permissionDenied
    case inUse
    /// Treated as "skipped", never as a failure.
    case notFound
    /// `xcrun` or `simctl` are missing.
    case toolUnavailable
    case commandFailed(exitCode: Int32, summary: String)
    case timedOut
    case cancelled
    case blockedByRunningApp(AppKind)
    /// A path rejected by `SafePathPolicy`: a bug, always reported.
    case unsafePath
    /// The root cannot be cleaned safely on this Mac (for example a symlink): skipped, not a bug.
    case unsupportedRoot
    /// `xcodebuild -downloadPlatform -buildVersion` refused the version: the selected Xcode cannot
    /// download it (C35, R9). Nothing was downloaded nor installed.
    case runtimeVersionUnavailable
    case unknown(domain: String, code: Int)

    // MARK: - Initializers

    init(_ error: any Error) {
        switch error {
        case let cleanupError as CleanupError:
            self = cleanupError
        case is CancellationError:
            self = .cancelled
        default:
            self = Self.map(error as NSError)
        }
    }

    // MARK: - Private Static Methods

    private static func map(_ error: NSError) -> CleanupError {
        if error.domain == NSPOSIXErrorDomain, let mapped = mapPOSIX(code: error.code) {
            return mapped
        }

        if error.domain == NSCocoaErrorDomain {
            if
                let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
                underlying.domain == NSPOSIXErrorDomain,
                let mapped = mapPOSIX(code: underlying.code)
            {
                return mapped
            }

            switch CocoaError.Code(rawValue: error.code) {
            case .fileWriteNoPermission, .fileReadNoPermission:
                return .permissionDenied
            case .fileNoSuchFile, .fileReadNoSuchFile:
                return .notFound
            default:
                break
            }
        }

        return .unknown(domain: error.domain, code: error.code)
    }

    private static func mapPOSIX(code: Int) -> CleanupError? {
        guard let rawValue = Int32(exactly: code) else { return nil }

        return switch POSIXErrorCode(rawValue: rawValue) {
        case .EACCES, .EPERM: .permissionDenied
        case .EBUSY: .inUse
        case .ENOENT: .notFound
        default: nil
        }
    }

    // MARK: - Nested Types

    enum AppKind: Sendable, Hashable {
        case xcode
        case simulator
    }

}
