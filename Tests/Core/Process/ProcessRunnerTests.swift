//
//  ProcessRunnerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
import Testing
@testable import CleanerXcode

/// Uses only harmless system binaries; the app itself only ever runs `/usr/bin/xcrun`.
struct ProcessRunnerTests {

    // MARK: - Private Properties

    private let runner = ProcessRunner()

    // MARK: - Public Methods

    @Test
    func returnsTheStandardOutputOfASuccessfulCommand() async throws {
        let output = try await runner.run(request("/bin/echo", ["hello", "world"]))

        #expect(String(bytes: output.standardOutput, encoding: .utf8) == "hello world\n")
        #expect(output.standardError.isEmpty)
    }

    @Test
    func keepsTheStandardErrorApartFromTheStandardOutput() async throws {
        let output = try await runner.run(request("/bin/sh", ["-c", "echo out; echo err 1>&2"]))

        #expect(String(bytes: output.standardOutput, encoding: .utf8) == "out\n")
        #expect(String(bytes: output.standardError, encoding: .utf8) == "err\n")
    }

    /// Both pipes overflow their buffers, so reading one after the other would deadlock.
    @Test
    func doesNotHangWhenBothOutputsAreLarge() async throws {
        let script = "head -c 1000000 /dev/zero; head -c 1000000 /dev/zero 1>&2"

        let output = try await runner.run(request("/bin/sh", ["-c", script], timeout: .seconds(30)))

        #expect(output.standardOutput.count == 1_000_000)
        #expect(output.standardError.count == 1_000_000)
    }

    @Test
    func aNonZeroExitBecomesCommandFailed() async throws {
        await #expect(throws: CleanupError.commandFailed(exitCode: 1, summary: "")) {
            try await runner.run(request("/usr/bin/false", []))
        }
    }

    @Test
    func theFailureSummaryIsTheSanitizedAndTruncatedStandardError() async throws {
        let longLine = String(repeating: "x", count: 5_000)
        let script = "echo 'cannot open /Users/someone/Secret/file' 1>&2; echo \(longLine) 1>&2; exit 3"

        let error = try await #require(throws: CleanupError.self) {
            try await runner.run(request("/bin/sh", ["-c", script]))
        }

        guard case let .commandFailed(exitCode, summary) = error else {
            Issue.record("Expected commandFailed, got \(error)")
            return
        }

        #expect(exitCode == 3)
        #expect(summary.hasPrefix("cannot open ~/Secret/file"))
        #expect(!summary.contains("someone"))
        #expect(summary.count == ProcessRunner.summaryLimit)
    }

    @Test
    func aMissingExecutableMeansTheToolIsUnavailable() async throws {
        await #expect(throws: CleanupError.toolUnavailable) {
            try await runner.run(request("/usr/bin/cleanerxcode-missing-tool", []))
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func terminatesTheProcessWhenItTimesOut() async throws {
        let launch = LaunchProbe()
        let runner = ProcessRunner(onLaunch: launch.record)
        let clock = ContinuousClock()
        let start = clock.now

        await #expect(throws: CleanupError.timedOut) {
            try await runner.run(request("/bin/sleep", ["30"], timeout: .milliseconds(200)))
        }

        #expect(clock.now - start < .seconds(10))
        #expect(try isGone(#require(launch.processIdentifier)))
    }

    @Test(.timeLimit(.minutes(1)))
    func terminatesTheProcessWhenTheCallerIsCancelled() async throws {
        let launch = LaunchProbe()
        let runner = ProcessRunner(onLaunch: launch.record)
        let sleepRequest = request("/bin/sleep", ["30"])
        let clock = ContinuousClock()
        let start = clock.now

        let task = Task {
            try await runner.run(sleepRequest)
        }

        await launch.waitForLaunch()
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(clock.now - start < .seconds(10))
        #expect(try isGone(#require(launch.processIdentifier)))
    }

    /// Waiting for long commands must not hold the cooperative threads other work needs.
    @Test(.timeLimit(.minutes(1)))
    func aQuickCommandFinishesWhileManyLongCommandsAreRunning() async throws {
        let longCommandCount = 40
        let launch = LaunchProbe()
        let longRunner = ProcessRunner(onLaunch: launch.record)
        let sleepRequest = request("/bin/sleep", ["20"], timeout: .seconds(30))
        let clock = ContinuousClock()

        let longCommands = Task {
            try await withThrowingTaskGroup(of: ProcessOutput.self) { group in
                for _ in 0..<longCommandCount {
                    group.addTask { try await longRunner.run(sleepRequest) }
                }

                try await group.waitForAll()
            }
        }

        defer { longCommands.cancel() }

        await launch.waitForLaunches(longCommandCount)

        let start = clock.now
        let output = try await runner.run(request("/bin/echo", ["quick"]))
        let elapsed = clock.now - start
        longCommands.cancel()
        _ = await longCommands.result

        #expect(String(bytes: output.standardOutput, encoding: .utf8) == "quick\n")
        #expect(elapsed < .seconds(5))
    }

    @Test
    func neverLaunchesWhenAlreadyCancelled() async throws {
        let launch = LaunchProbe()
        let runner = ProcessRunner(onLaunch: launch.record)
        let echoRequest = request("/bin/echo", ["hi"])

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await runner.run(echoRequest)
        }

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(launch.processIdentifier == nil)
    }

    @Test
    @MainActor
    func launchesTheProcessOffTheMainThreadEvenWhenCalledFromIt() async throws {
        let launch = LaunchProbe()
        let runner = ProcessRunner(onLaunch: launch.record)

        _ = try await runner.run(request("/bin/echo", ["hi"]))

        #expect(launch.launchedOnMainThread == false)
    }

    @Test
    func xcrunRequestsUseTheAbsoluteXcrunPathAndTheTimeoutsOfThePlan() {
        let list = ProcessRequest.xcrun(["simctl", "list", "--json", "devices"])

        #expect(list.executableURL == URL(filePath: "/usr/bin/xcrun"))
        #expect(list.arguments == ["simctl", "list", "--json", "devices"])
        #expect(list.timeout == .seconds(60))
        #expect(ProcessRequest.eraseAllTimeout == .seconds(600))
        #expect(ProcessRequest.runtimeDeleteTimeout == .seconds(1_800))
    }

    // MARK: - Private Methods

    private func request(_ path: String, _ arguments: [String], timeout: Duration = .seconds(10)) -> ProcessRequest {
        ProcessRequest(executableURL: URL(filePath: path), arguments: arguments, timeout: timeout)
    }

    /// `kill(pid, 0)` fails with `ESRCH` once the process no longer exists.
    private func isGone(_ processIdentifier: pid_t) -> Bool {
        kill(processIdentifier, 0) == -1 && errno == ESRCH
    }

    // MARK: - Nested Types

    nonisolated private final class LaunchProbe: Sendable {

        // MARK: - Public Properties

        var processIdentifier: pid_t? {
            state.withLock { $0.processIdentifier }
        }

        var launchedOnMainThread: Bool? {
            state.withLock { $0.launchedOnMainThread }
        }

        // MARK: - Private Properties

        private let state = Mutex(State())
        private let launches = AsyncStream.makeStream(of: Void.self)

        // MARK: - Public Methods

        func record(_ processIdentifier: pid_t) {
            state.withLock { state in
                state.processIdentifier = processIdentifier
                state.launchedOnMainThread = Thread.isMainThread
            }

            launches.continuation.yield()
        }

        func waitForLaunch() async {
            await waitForLaunches(1)
        }

        func waitForLaunches(_ count: Int) async {
            var iterator = launches.stream.makeAsyncIterator()

            for _ in 0..<count {
                _ = await iterator.next()
            }
        }

        // MARK: - Nested Types

        private struct State {
            var processIdentifier: pid_t?
            var launchedOnMainThread: Bool?
        }

    }

}
