//
//  XcodebuildRuntimeDownloader.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// Downloads and installs a simulator runtime with `xcodebuild -downloadPlatform` (C30), without a
/// shell and through `xcrun`, so it uses the same Xcode as `simctl`. Its output is not documented:
/// each line is read as it arrives by `RuntimeDownloadOutputParser`, and the steps it recognizes are
/// reported as the progress (C34).
nonisolated struct XcodebuildRuntimeDownloader: RuntimeDownloading {

    // MARK: - Private Properties

    private let runner: any ProcessRunning

    // MARK: - Initializers

    init(runner: any ProcessRunning = ProcessRunner()) {
        self.runner = runner
    }

    // MARK: - Public Methods

    func download(
        _ platform: RuntimePlatform,
        buildVersion: RuntimeBuildVersion?,
        onProgress: @escaping @Sendable (RuntimeDownloadEvent) -> Void
    ) async throws {
        var arguments = ["xcodebuild", "-downloadPlatform", platform.rawValue]

        if let buildVersion {
            arguments += ["-buildVersion", buildVersion.rawValue]
        }

        do {
            _ = try await runner.run(.xcrun(arguments, timeout: ProcessRequest.runtimeDownloadTimeout)) { line in
                if let event = RuntimeDownloadOutputParser.event(from: line) {
                    onProgress(event)
                }
            }
        } catch {
            throw XcrunFailure.normalized(error)
        }
    }

}
