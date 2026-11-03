//
//  ProcessRunning.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated protocol ProcessRunning: Sendable {
    /// Runs the command off the caller's actor. A non-zero exit throws
    /// `CleanupError.commandFailed`, a timeout `.timedOut`, a missing executable
    /// `.toolUnavailable`, and cancellation terminates the process and throws `CancellationError`.
    func run(_ request: ProcessRequest) async throws -> ProcessOutput

    /// Same contract as `run(_:)`. Each line of standard output, split at "\n", "\r" or "\r\n"
    /// (empty lines dropped), is also handed to `onStandardOutputLine` as it arrives, in order, one
    /// at a time and off the main actor (C34). Every call happens before this method returns or
    /// throws. The handler must be quick: reading waits for it.
    func run(
        _ request: ProcessRequest,
        onStandardOutputLine: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessOutput
}

nonisolated extension ProcessRunning {

    // MARK: - Public Methods

    /// Conformers that cannot stream hand the lines over once the command has succeeded.
    func run(
        _ request: ProcessRequest,
        onStandardOutputLine: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessOutput {
        let output = try await run(request)

        var splitter = OutputLineSplitter()

        (splitter.append(output.standardOutput) + splitter.finish()).forEach(onStandardOutputLine)
        return output
    }

}
