//
//  CoreSimulatorServiceRestarter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Darwin
import Foundation

nonisolated protocol SimulatorServiceRestarting: Sendable {
    func restart() throws
}

nonisolated protocol ProcessListing: Sendable {
    func processIdentifiers(withExecutableNamed name: String) -> [pid_t]
    func terminate(_ processIdentifier: pid_t) throws
}

/// Restarts the CoreSimulatorService without rebooting the Mac: it is an on-demand XPC service,
/// so launchd starts it again on the next `simctl` call (R10). Needs live validation in C27.
nonisolated struct CoreSimulatorServiceRestarter: SimulatorServiceRestarting {

    // MARK: - Public Properties

    static let executableName = "com.apple.CoreSimulator.CoreSimulatorService"

    // MARK: - Private Properties

    private let processes: any ProcessListing

    // MARK: - Initializers

    init(processes: any ProcessListing = LibprocProcessListing()) {
        self.processes = processes
    }

    // MARK: - Public Methods

    func restart() throws {
        for processIdentifier in processes.processIdentifiers(withExecutableNamed: Self.executableName) {
            try processes.terminate(processIdentifier)
        }
    }

}

nonisolated struct LibprocProcessListing: ProcessListing {

    // MARK: - Private Properties

    /// `PROC_PIDPATHINFO_MAXSIZE` is a C macro Swift does not import.
    private static let pathBufferSize = 4 * Int(MAXPATHLEN)

    // MARK: - Private Static Methods

    private static func executablePath(of processIdentifier: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: pathBufferSize)

        let length = proc_pidpath(processIdentifier, &buffer, UInt32(buffer.count))

        guard length > 0 else { return nil }

        return String(validating: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    // MARK: - Public Methods

    /// Compares the last component of the full executable path, because `proc_name` truncates
    /// long names such as the service's.
    func processIdentifiers(withExecutableNamed name: String) -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)

        guard estimate > 0 else { return [] }

        // Room for processes started between the two calls.
        var identifiers = [pid_t](repeating: 0, count: Int(estimate) * 2)

        let count = identifiers.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }

        return identifiers.prefix(Int(max(count, 0))).filter { processIdentifier in
            guard processIdentifier > 0, let path = Self.executablePath(of: processIdentifier) else { return false }

            return URL(filePath: path).lastPathComponent == name
        }
    }

    /// A process that already exited, or that belongs to another user, is left alone. The
    /// identifier could in theory be reused between the listing and the signal; that race is
    /// accepted, because only `SIGTERM` is sent and other users' processes refuse it.
    func terminate(_ processIdentifier: pid_t) throws {
        guard kill(processIdentifier, SIGTERM) != 0 else { return }

        let code = errno

        guard code != ESRCH, code != EPERM else { return }

        throw CleanupError(POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO))
    }

}
