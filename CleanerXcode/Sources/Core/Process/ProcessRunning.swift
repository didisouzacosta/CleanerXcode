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
}
