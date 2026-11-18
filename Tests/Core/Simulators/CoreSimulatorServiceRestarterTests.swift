//
//  CoreSimulatorServiceRestarterTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
import Testing
@testable import CleanerXcode

/// Never signals the real CoreSimulatorService: the real listing is checked against the test
/// host itself and the real terminate against a `sleep` the test starts.
struct CoreSimulatorServiceRestarterTests {

    // MARK: - Public Methods

    @Test
    func terminatesEveryProcessRunningTheServiceExecutable() throws {
        let processes = ProcessListingStub(pids: [CoreSimulatorServiceRestarter.executableName: [101, 202]])

        try CoreSimulatorServiceRestarter(processes: processes).restart()

        #expect(processes.terminated == [101, 202])
        #expect(CoreSimulatorServiceRestarter.executableName == "com.apple.CoreSimulator.CoreSimulatorService")
    }

    @Test
    func doesNothingWhenTheServiceIsNotRunning() throws {
        let processes = ProcessListingStub(pids: [:])

        try CoreSimulatorServiceRestarter(processes: processes).restart()

        #expect(processes.terminated.isEmpty)
    }

    @Test
    func theRealListingFindsProcessesByTheirFullExecutableName() throws {
        let executableName = try URL(filePath: #require(CommandLine.arguments.first)).lastPathComponent

        let pids = LibprocProcessListing().processIdentifiers(withExecutableNamed: executableName)

        #expect(pids.contains(getpid()))
        #expect(LibprocProcessListing().processIdentifiers(withExecutableNamed: "cleanerxcode-no-such-process").isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func theRealTerminateSendsSigtermToTheProcess() async throws {
        let sleeper = Process()
        sleeper.executableURL = URL(filePath: "/bin/sleep")
        sleeper.arguments = ["30"]
        let exited = AsyncStream.makeStream(of: Process.TerminationReason.self)
        sleeper.terminationHandler = { exited.continuation.yield($0.terminationReason) }
        try sleeper.run()

        try LibprocProcessListing().terminate(sleeper.processIdentifier)

        var reasons = exited.stream.makeAsyncIterator()
        #expect(await reasons.next() == .uncaughtSignal)
        #expect(sleeper.terminationStatus == SIGTERM)
    }

    // MARK: - Nested Types

    nonisolated private final class ProcessListingStub: ProcessListing, Sendable {

        // MARK: - Public Properties

        var terminated: [pid_t] {
            state.withLock { $0 }
        }

        // MARK: - Private Properties

        private let pids: [String: [pid_t]]
        private let state = Mutex<[pid_t]>([])

        // MARK: - Initializers

        init(pids: [String: [pid_t]]) {
            self.pids = pids
        }

        // MARK: - Public Methods

        func processIdentifiers(withExecutableNamed name: String) -> [pid_t] {
            pids[name, default: []]
        }

        func terminate(_ processIdentifier: pid_t) throws {
            state.withLock { $0.append(processIdentifier) }
        }

    }

}
