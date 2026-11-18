//
//  XcrunFailure.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// The failures of `xcrun` itself, as opposed to the tool it runs (`simctl`, `xcodebuild`).
nonisolated enum XcrunFailure {

    // MARK: - Public Properties

    /// `xcrun` exits with 72 when it cannot find the tool, for example with only the Command Line
    /// Tools selected.
    static let toolNotFoundExitCode: Int32 = 72
    /// `xcrun`'s own errors, such as a deleted Xcode that is still selected or a missing
    /// `DEVELOPER_DIR` (exit 1). Neither `simctl` nor `xcodebuild` use this prefix.
    static let errorPrefix = "xcrun: error:"

    // MARK: - Public Methods

    /// `.toolUnavailable` for xcrun's own failures; anything else unchanged.
    static func normalized(_ error: any Error) -> any Error {
        guard
            let failure = error as? CleanupError,
            case let .commandFailed(exitCode, summary) = failure,
            exitCode == toolNotFoundExitCode || summary.hasPrefix(errorPrefix)
        else {
            return error
        }

        return CleanupError.toolUnavailable
    }

}
