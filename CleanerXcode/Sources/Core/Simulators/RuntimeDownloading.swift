//
//  RuntimeDownloading.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

nonisolated protocol RuntimeDownloading: Sendable {
    /// Downloads and installs the simulator runtime of `platform` (the selected Xcode's version
    /// when `buildVersion` is nil). Cancellation terminates the download and throws
    /// `CancellationError`; missing tools throw `.toolUnavailable`. `onProgress` receives each
    /// recognized step of the output, in order, off the main actor and never after this method
    /// returns; output it does not recognize reports nothing (C34).
    func download(
        _ platform: RuntimePlatform,
        buildVersion: RuntimeBuildVersion?,
        onProgress: @escaping @Sendable (RuntimeDownloadEvent) -> Void
    ) async throws
}

nonisolated extension RuntimeDownloading {
    /// Without progress.
    func download(_ platform: RuntimePlatform, buildVersion: RuntimeBuildVersion?) async throws {
        try await download(platform, buildVersion: buildVersion) { _ in }
    }
}
