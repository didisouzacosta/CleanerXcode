//
//  ProcessRunner.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Runs a command without a shell. Both outputs are read in parallel so a full pipe never blocks
/// the process, the timeout races the process in a task group, and cancellation terminates it.
nonisolated struct ProcessRunner: ProcessRunning {

    // MARK: - Public Properties

    /// The longest standard error kept in `CleanupError.commandFailed`, after sanitization.
    static let summaryLimit = 500

    // MARK: - Private Properties

    /// Called with the process identifier right after launch; tests use it to check termination.
    private let onLaunch: @Sendable (pid_t) -> Void

    // MARK: - Initializers

    init(onLaunch: @escaping @Sendable (pid_t) -> Void = { _ in }) {
        self.onLaunch = onLaunch
    }

    // MARK: - Private Static Methods

    private static func output(from completion: Completion) throws -> ProcessOutput {
        guard completion.reason == .exit, completion.status == 0 else {
            // Output that is not UTF-8 is dropped from the summary rather than guessed.
            let standardError = String(bytes: completion.standardError, encoding: .utf8) ?? ""
            let summary = SentryEventSanitizer.sanitize(text: standardError)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            throw CleanupError.commandFailed(exitCode: completion.status, summary: String(summary.prefix(summaryLimit)))
        }

        return ProcessOutput(standardOutput: completion.standardOutput, standardError: completion.standardError)
    }

    /// `FileHandle.bytes` blocks a cooperative thread per pipe until the process ends, which
    /// starves the pool during long commands, so the reads go through `readabilityHandler`. With
    /// `onLine`, each line is also handed over as it arrives; the last one without a separator only
    /// at the end of the output, never after a cancellation or a timeout (C34).
    private static func readAll(_ handle: FileHandle, onLine: (@Sendable (String) -> Void)?) async -> Data {
        let (chunks, continuation) = AsyncStream.makeStream(of: Data.self)

        // A cancelled read (timeout or caller) stops listening instead of waiting for EOF.
        continuation.onTermination = { _ in
            handle.readabilityHandler = nil
        }

        handle.readabilityHandler = { handle in
            let chunk = handle.availableData

            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                continuation.finish()
                return
            }

            continuation.yield(chunk)
        }

        var data = Data()

        var splitter = OutputLineSplitter()

        for await chunk in chunks {
            data.append(chunk)

            if let onLine {
                splitter.append(chunk).forEach(onLine)
            }
        }

        if let onLine, !Task.isCancelled {
            splitter.finish().forEach(onLine)
        }

        return data
    }

    // MARK: - Public Methods

    @concurrent
    func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        try await perform(request, standardOutputLines: nil)
    }

    @concurrent
    func run(
        _ request: ProcessRequest,
        onStandardOutputLine: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessOutput {
        try await perform(request, standardOutputLines: onStandardOutputLine)
    }

    // MARK: - Private Methods

    private func perform(
        _ request: ProcessRequest,
        standardOutputLines: (@Sendable (String) -> Void)?
    ) async throws -> ProcessOutput {
        try Task.checkCancellation()

        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = standardOutput
        process.standardError = standardError

        let completion = try await withThrowingTaskGroup(of: Completion?.self) { group in
            group.addTask {
                try await execute(
                    process,
                    standardOutput: standardOutput,
                    standardError: standardError,
                    standardOutputLines: standardOutputLines
                )
            }

            group.addTask {
                try await Task.sleep(for: request.timeout)
                return nil
            }

            let first = try await group.next() ?? nil
            group.cancelAll()

            guard let first else {
                // Also done by the `onCancel` that `cancelAll()` triggers; kept so the timeout path
                // never depends on that.
                if process.isRunning {
                    process.terminate()
                }

                throw CleanupError.timedOut
            }

            return first
        }

        // A process terminated because the caller was cancelled is not a command failure. Usually
        // the timeout child already threw, so this only covers the process finishing first.
        try Task.checkCancellation()

        return try Self.output(from: completion)
    }

    private func execute(
        _ process: Process,
        standardOutput: Pipe,
        standardError: Pipe,
        standardOutputLines: (@Sendable (String) -> Void)?
    ) async throws -> Completion {
        try await withTaskCancellationHandler {
            async let output = Self.readAll(standardOutput.fileHandleForReading, onLine: standardOutputLines)
            async let errors = Self.readAll(standardError.fileHandleForReading, onLine: nil)

            let (status, reason) = try await waitForExit(of: process, pipes: [standardOutput, standardError])
            return await Completion(status: status, reason: reason, standardOutput: output, standardError: errors)
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    private func waitForExit(of process: Process, pipes: [Pipe]) async throws -> (Int32, Process.TerminationReason) {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: (finished.terminationStatus, finished.terminationReason))
            }

            do {
                // Covers a cancellation that lands after the check at the start of `run`.
                try Task.checkCancellation()
                try process.run()
            } catch {
                process.terminationHandler = nil

                // Never launched, so close the write ends for the readers to reach the end.
                for pipe in pipes {
                    try? pipe.fileHandleForWriting.close()
                }

                continuation.resume(throwing: error is CancellationError ? error : CleanupError.toolUnavailable)
                return
            }

            onLaunch(process.processIdentifier)

            // Cancelled between the check and the launch: the handler saw nothing to terminate.
            if Task.isCancelled, process.isRunning {
                process.terminate()
            }
        }
    }

    // MARK: - Nested Types

    private struct Completion: Sendable {
        let status: Int32
        let reason: Process.TerminationReason
        let standardOutput: Data
        let standardError: Data
    }

}
