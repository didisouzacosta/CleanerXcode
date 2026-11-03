//
//  RuntimeDownloading.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

nonisolated protocol RuntimeDownloading: Sendable {
    /// Downloads and installs the simulator runtime of `platform` (the selected Xcode's version
    /// when `buildVersion` is nil). Cancellation terminates the download and throws
    /// `CancellationError`; missing tools throw `.toolUnavailable`.
    func download(_ platform: RuntimePlatform, buildVersion: RuntimeBuildVersion?) async throws
}
