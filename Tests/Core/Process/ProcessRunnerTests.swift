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

    // MARK: - Streaming (C34)

    @Test
    func streamsEachStandardOutputLineSplitAtReturnsAndNewlines() async throws {
        let lines = LineCollector()
        let format = [
            "Finding content...\\n",
            "\\rDownloading X: 0,1%% (3,6 MB of 3,76 GB)",
            "\\rDownloading X: 0,2%% (6,7 MB of 3,76 GB)\\nDone",
        ].joined()
        let expected = [
            "Finding content...\n",
            "\rDownloading X: 0,1% (3,6 MB of 3,76 GB)",
            "\rDownloading X: 0,2% (6,7 MB of 3,76 GB)\nDone",
        ].joined()

        let output = try await runner.run(request("/usr/bin/printf", [format]), onStandardOutputLine: lines.append)

        #expect(lines.all == [
            "Finding content...",
            "Downloading X: 0,1% (3,6 MB of 3,76 GB)",
            "Downloading X: 0,2% (6,7 MB of 3,76 GB)",
            "Done",
        ])
        #expect(String(bytes: output.standardOutput, encoding: .utf8) == expected)
    }

    /// The first line arrives while `tail -f` is still running, which only ends when cancelled; the
    /// partial line after it is never handed over.
    @Test(.timeLimit(.minutes(1)))
    func deliversLinesWhileTheCommandIsStillRunningAndCancelsIt() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let file = try progressFile(in: fixture)
        let launch = LaunchProbe()
        let runner = ProcessRunner(onLaunch: launch.record)
        let lines = LineCollector()
        let tailRequest = request("/usr/bin/tail", ["-n", "+1", "-f", file.path(percentEncoded: false)])
        let (arrived, continuation) = AsyncStream.makeStream(of: String.self)
        let clock = ContinuousClock()
        let start = clock.now

        let task = Task {
            try await runner.run(tailRequest) { line in
                lines.append(line)
                continuation.yield(line)
            }
        }

        var iterator = arrived.makeAsyncIterator()

        #expect(await iterator.next() == "first line")
        #expect(try isRunning(#require(launch.processIdentifier)))

        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(lines.all == ["first line"], "The pending \"partial\" is dropped on cancel.")
        #expect(clock.now - start < .seconds(10))
        #expect(try isGone(#require(launch.processIdentifier)))
    }

    /// The pending "partial" line is not handed over on timeout.
    @Test(.timeLimit(.minutes(1)))
    func timesOutAStreamingCommandAndTerminatesIt() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let file = try progressFile(in: fixture)
        let launch = LaunchProbe()
        let runner = ProcessRunner(onLaunch: launch.record)
        let lines = LineCollector()
        let tailRequest = request(
            "/usr/bin/tail",
            ["-n", "+1", "-f", file.path(percentEncoded: false)],
            timeout: .milliseconds(500)
        )

        await #expect(throws: CleanupError.timedOut) {
            try await runner.run(tailRequest, onStandardOutputLine: lines.append)
        }

        #expect(lines.all == ["first line"], "The pending \"partial\" is dropped on timeout.")
        #expect(try isGone(#require(launch.processIdentifier)))
    }

    @Test
    func streamingKeepsTheCommandFailedContract() async throws {
        let lines = LineCollector()

        await #expect(throws: CleanupError.commandFailed(exitCode: 1, summary: "")) {
            try await runner.run(request("/usr/bin/false", []), onStandardOutputLine: lines.append)
        }

        #expect(lines.all.isEmpty)
    }

    /// Runners that cannot stream, such as the test fakes, hand the lines over after success.
    @Test
    func theDefaultHandsTheLinesOverAfterSuccess() async throws {
        let arguments = ["xcodebuild", "-downloadPlatform", "iOS"]
        let spy = ProcessRunnerSpy(responses: [arguments: .success("a\rb\nc")])
        let failing = ProcessRunnerSpy(responses: [arguments: .failure(.timedOut)])
        let lines = LineCollector()
        let noLines = LineCollector()

        _ = try await spy.run(.xcrun(arguments), onStandardOutputLine: lines.append)

        await #expect(throws: CleanupError.timedOut) {
            try await failing.run(.xcrun(arguments), onStandardOutputLine: noLines.append)
        }

        #expect(lines.all == ["a", "b", "c"])
        #expect(noLines.all.isEmpty)
    }

    // MARK: - Private Methods

    private func request(_ path: String, _ arguments: [String], timeout: Duration = .seconds(10)) -> ProcessRequest {
        ProcessRequest(executableURL: URL(filePath: path), arguments: arguments, timeout: timeout)
    }

    /// A complete line, then a partial one that only an end of output would hand over.
    private func progressFile(in fixture: TemporaryDirectoryFixture) throws -> URL {
        let file = fixture.url.appending(path: "progress.txt", directoryHint: .notDirectory)

        try Data("first line\npartial".utf8).write(to: file)
        return file
    }

    private func isRunning(_ processIdentifier: pid_t) -> Bool {
        kill(processIdentifier, 0) == 0
    }

    /// `kill(pid, 0)` fails with `ESRCH` once the process no longer exists.
    private func isGone(_ processIdentifier: pid_t) -> Bool {
        kill(processIdentifier, 0) == -1 && errno == ESRCH
    }

    // MARK: - Nested Types

    /// The lines a streaming run handed over, in order.
    nonisolated private final class LineCollector: Sendable {

        // MARK: - Public Properties

        var all: [String] {
            lines.withLock { $0 }
        }

        // MARK: - Private Properties

        private let lines = Mutex<[String]>([])

        // MARK: - Public Methods

        func append(_ line: String) {
            lines.withLock { $0.append(line) }
        }

    }

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
