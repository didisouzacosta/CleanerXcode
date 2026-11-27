//
//  XcodebuildRuntimeDownloader.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Synchronization

/// Downloads and installs a simulator runtime with `xcodebuild -downloadPlatform` (C30), without a
/// shell and through `xcrun`, so it uses the same Xcode as `simctl`. Its output is not documented:
/// each line is read as it arrives by `RuntimeDownloadOutputParser`, and the steps it recognizes are
/// reported as the progress (C34). A version the selected Xcode refuses ("… is not available for
/// download.", on either stream and whatever the exit status) throws `.runtimeVersionUnavailable`
/// (C35, R9).
nonisolated struct XcodebuildRuntimeDownloader: RuntimeDownloading {

    // MARK: - Private Properties

    private let runner: any ProcessRunning

    // MARK: - Initializers

    init(runner: any ProcessRunning = ProcessRunner()) {
        self.runner = runner
    }

    // MARK: - Private Static Methods

    private static func mentionsRefusal(_ text: String) -> Bool {
        text.split(whereSeparator: \.isNewline)
            .contains { RuntimeDownloadOutputParser.isUnavailableVersion(String($0)) }
    }

    /// A failure whose standard error (the summary) holds the refusal.
    private static func isRefusal(_ error: any Error) -> Bool {
        guard case let .commandFailed(_, summary) = error as? CleanupError else { return false }

        return mentionsRefusal(summary)
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

        let refusal = RefusalMark()
        let output: ProcessOutput

        do {
            output = try await runner.run(.xcrun(arguments, timeout: ProcessRequest.runtimeDownloadTimeout)) { line in
                if RuntimeDownloadOutputParser.isUnavailableVersion(line) {
                    refusal.mark()
                }

                if let event = RuntimeDownloadOutputParser.event(from: line) {
                    onProgress(event)
                }
            }
        } catch {
            if !(error is CancellationError), refusal.isMarked || Self.isRefusal(error) {
                throw CleanupError.runtimeVersionUnavailable
            }

            throw XcrunFailure.normalized(error)
        }

        // The lines arrive before `run` returns (C34), so the mark is final here.
        if refusal.isMarked || Self.mentionsRefusal(String(bytes: output.standardError, encoding: .utf8) ?? "") {
            throw CleanupError.runtimeVersionUnavailable
        }
    }

    // MARK: - Nested Types

    /// Set from the output handler, off the caller's actor, and read once the command has ended.
    nonisolated private final class RefusalMark: Sendable {

        // MARK: - Public Properties

        var isMarked: Bool {
            flag.withLock { $0 }
        }

        // MARK: - Private Properties

        private let flag = Mutex(false)

        // MARK: - Public Methods

        func mark() {
            flag.withLock { $0 = true }
        }

    }

}
