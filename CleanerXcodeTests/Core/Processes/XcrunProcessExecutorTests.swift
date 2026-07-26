import Darwin
import Foundation
import Testing

@testable import CleanerXcode

@Suite(.serialized)
struct XcrunProcessExecutorTests {

    // MARK: - Public Methods

    @Test
    func exposesOnlyTheTwoTypedOperationsWithExactArguments() {
        #expect(XcrunOperation.allCases == [
            .deleteUnavailableSimulators,
            .shutdownAllSimulators
        ])
        #expect(XcrunOperation.deleteUnavailableSimulators.arguments == [
            "simctl",
            "delete",
            "unavailable"
        ])
        #expect(XcrunOperation.shutdownAllSimulators.arguments == [
            "simctl",
            "shutdown",
            "all"
        ])
        #expect(ProcessOutputPolicy.defaultLimitPerStream == 8 * 1_024 * 1_024)
        #expect(ProcessOutputPolicy().limitPerStream == 8 * 1_024 * 1_024)
    }

    @Test
    func preCancelledExecutionDoesNotLaunchAProcess() async {
        let launcher = ProcessLauncherSpy(RunningProcessFake())
        let executor = XcrunProcessExecutor(launcher)
        let task = Task.detached {
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            return try await executor.execute(.deleteUnavailableSimulators, timeout: .seconds(1))
        }

        await #expect(throws: ProcessExecutionError.cancelled) {
            try await task.value
        }
        #expect(launcher.launchCount == 0)
    }

    @Test
    func returnsCapturedOutputFromTheTypedOperation() async throws {
        let completion = ProcessCompletion(
            standardOutput: Data("deleted\n".utf8),
            standardError: Data(),
            terminationStatus: 0
        )
        let process = RunningProcessFake(completion)
        let launcher = ProcessLauncherSpy(process)
        let executor = XcrunProcessExecutor(launcher)

        let result = try await executor.execute(.deleteUnavailableSimulators, timeout: .seconds(1))

        #expect(launcher.operations == [.deleteUnavailableSimulators])
        #expect(result.standardOutput == "deleted\n")
        #expect(result.standardError.isEmpty)
        #expect(result.terminationStatus == 0)
        #expect(process.reapCount == 1)
        #expect(process.observerCount == 0)
    }

    @Test
    func reportsLaunchFailuresWithoutExposingAnArbitraryExecutable() async {
        let executor = XcrunProcessExecutor(FailingProcessLauncher())

        do {
            _ = try await executor.execute(.deleteUnavailableSimulators, timeout: .seconds(1))
            Issue.record("Expected a launch failure.")
        } catch let error as ProcessExecutionError {
            #expect(error == .launchFailed(LaunchError.expected.localizedDescription))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func observationFailureWhileChildIsAliveTerminatesKillsAndReapsBeforeReturning() async {
        let killedCompletion = ProcessCompletion(
            standardOutput: Data(),
            standardError: Data(),
            terminationStatus: 137
        )
        let process = RunningProcessFake(
            killCompletion: killedCompletion,
            observationError: LaunchError.expected
        )
        let executor = XcrunProcessExecutor(
            ProcessLauncherSpy(process),
            supervisorClock: ImmediateMonotonicClock()
        )

        await #expect(throws: ProcessExecutionError.self) {
            try await executor.execute(
                .deleteUnavailableSimulators,
                timeout: .seconds(60)
            )
        }
        #expect(process.signals == [.termination, .kill])
        #expect(process.reapCount == 1)
    }

    @Test
    func preservesTheCompleteResultForANonzeroExit() async {
        let expectedResult = ProcessExecutionResult(
            standardOutput: "partial output",
            standardError: "simctl failed",
            terminationStatus: 7
        )
        let completion = ProcessCompletion(
            standardOutput: Data(expectedResult.standardOutput.utf8),
            standardError: Data(expectedResult.standardError.utf8),
            terminationStatus: expectedResult.terminationStatus
        )
        let executor = XcrunProcessExecutor(ProcessLauncherSpy(RunningProcessFake(completion)))

        do {
            _ = try await executor.execute(.deleteUnavailableSimulators, timeout: .seconds(1))
            Issue.record("Expected a nonzero-exit error.")
        } catch let error as ProcessExecutionError {
            #expect(error == .nonzeroExit(expectedResult))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func resistantTerminationIsKilledAndReapedExactlyOnce() async {
        let killedCompletion = ProcessCompletion(
            standardOutput: Data(),
            standardError: Data("killed".utf8),
            terminationStatus: 137
        )
        let process = RunningProcessFake(killCompletion: killedCompletion)
        let executor = XcrunProcessExecutor(
            ProcessLauncherSpy(process),
            timeoutClock: ImmediateMonotonicClock(),
            supervisorClock: ImmediateMonotonicClock()
        )

        await #expect(throws: ProcessExecutionError.timeout) {
            try await executor.execute(.shutdownAllSimulators, timeout: .milliseconds(1))
        }
        #expect(process.signals == [.termination, .kill])
        #expect(process.reapCount == 1)
        #expect(process.observerCount == 0)
    }

    @Test
    func signalFailuresDoNotReturnUntilTheChildEventuallyExitsAndIsReaped() async {
        let completion = ProcessCompletion(
            standardOutput: Data(),
            standardError: Data(),
            terminationStatus: 0
        )
        let process = RunningProcessFake(
            terminationError: SignalError.expected,
            killError: SignalError.expected
        )
        let executor = XcrunProcessExecutor(
            ProcessLauncherSpy(process),
            timeoutClock: ImmediateMonotonicClock(),
            supervisorClock: ImmediateMonotonicClock()
        )
        let probe = CompletionProbe()
        let task = Task {
            defer {
                probe.complete()
            }

            return try await executor.execute(.shutdownAllSimulators, timeout: .milliseconds(1))
        }

        await process.waitForSignalCount(2)
        #expect(!probe.isComplete)
        #expect(process.reapCount == 0)
        process.release(completion)

        do {
            _ = try await task.value
            Issue.record("Expected a signal failure.")
        } catch let error as ProcessExecutionError {
            #expect(error == .signalFailed(.termination, SignalError.expected.localizedDescription))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(probe.isComplete)
        #expect(process.reapCount == 1)
        #expect(process.observerCount == 0)
    }

    @Test
    func cancellationDuringTimeoutCleanupStillKillsAndReapsBeforeReturning() async {
        let killedCompletion = ProcessCompletion(
            standardOutput: Data(),
            standardError: Data(),
            terminationStatus: 137
        )
        let process = RunningProcessFake(killCompletion: killedCompletion)
        let executor = XcrunProcessExecutor(
            ProcessLauncherSpy(process),
            timeoutClock: ImmediateMonotonicClock(),
            supervisorClock: SuspendingMonotonicClock()
        )
        let task = Task {
            try await executor.execute(.shutdownAllSimulators, timeout: .milliseconds(1))
        }

        await process.waitForSignalCount(1)
        task.cancel()

        await #expect(throws: ProcessExecutionError.cancelled) {
            try await task.value
        }
        #expect(process.signals == [.termination, .kill])
        #expect(process.reapCount == 1)
        #expect(process.observerCount == 0)
    }

    @Test
    func cancellationAfterLaunchTerminatesAndReapsBeforeReturning() async {
        let killedCompletion = ProcessCompletion(
            standardOutput: Data(),
            standardError: Data(),
            terminationStatus: 137
        )
        let process = RunningProcessFake(killCompletion: killedCompletion)
        let launcher = ProcessLauncherSpy(process)
        let executor = XcrunProcessExecutor(launcher)
        let task = Task {
            try await executor.execute(.shutdownAllSimulators, timeout: .seconds(60))
        }

        await launcher.waitUntilLaunched()
        task.cancel()

        await #expect(throws: ProcessExecutionError.cancelled) {
            try await task.value
        }
        #expect(process.reapCount == 1)
        #expect(process.observerCount == 0)
    }

    @Test
    func simulatorControllerUsesOnlyTypedOperations() async throws {
        let executor = ProcessExecutorSpy()
        let controller = SimulatorControlService(executor)

        _ = try await controller.deleteUnavailable()
        _ = try await controller.shutdownAll()

        #expect(executor.operations == [
            .deleteUnavailableSimulators,
            .shutdownAllSimulators
        ])
    }

    @Test
    func posixLauncherConstructsTheExactRestrictedSpawnAndOwnsReturnedDescriptors() async throws {
        let operations = POSIXOperationsSpy(
            [.exited(0)],
            descriptorData: [
                41: Data("stdout".utf8),
                42: Data("stderr".utf8)
            ]
        )
        let launcher = POSIXProcessLauncher(operations)
        let process = try await launcher.launch(.deleteUnavailableSimulators)

        let completion = try await process.reap()

        let expectedEnvironment = ProcessInfo.processInfo.environment
            .map { "\($0.key)=\($0.value)" }
            .sorted()
        #expect(operations.spawnRequests == [
            CleanupProcessSpawnRequest(
                arguments: ["/usr/bin/xcrun", "simctl", "delete", "unavailable"],
                attributeFlags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT),
                environment: expectedEnvironment,
                executablePath: "/usr/bin/xcrun",
                standardErrorTarget: STDERR_FILENO,
                standardOutputTarget: STDOUT_FILENO
            )
        ])
        #expect(operations.closedDescriptors.sorted() == [41, 42])
        #expect(operations.readDescriptors.sorted() == [41, 42])
        #expect(operations.waitRequests == [.init(processIdentifier: 123, noHang: false)])
        #expect(completion.standardOutput == Data("stdout".utf8))
        #expect(completion.standardError == Data("stderr".utf8))
        #expect(completion.terminationStatus == 0)
    }

    @Test
    func abandoningAProcessClosesBothUnreadCaptureDescriptorsExactlyOnce() async throws {
        let operations = POSIXOperationsSpy([])
        var process: (any RunningProcess)? = try await POSIXProcessLauncher(operations)
            .launch(.shutdownAllSimulators)

        #expect(process != nil)
        process = nil

        #expect(operations.closedDescriptors.sorted() == [41, 42])
        #expect(operations.readDescriptors.isEmpty)
    }

    @Test
    func posixBackendRetriesOnlyInterruptedWaitAndDecodesASignal() async throws {
        let operations = POSIXOperationsSpy([.interrupted, .signaled(9)])
        let process = try await POSIXProcessLauncher(operations).launch(.shutdownAllSimulators)

        let completion = try await process.reap()

        #expect(completion.terminationStatus == 137)
        #expect(operations.waitRequests == [
            .init(processIdentifier: 123, noHang: false),
            .init(processIdentifier: 123, noHang: false)
        ])
    }

    @Test
    func posixBackendRejectsUnprovenNoChildInsteadOfInventingStatusZero() async throws {
        let operations = POSIXOperationsSpy([.noChild])
        let process = try await POSIXProcessLauncher(operations).launch(.shutdownAllSimulators)

        await #expect(throws: POSIXLifecycleError.self) {
            try await process.reap()
        }
    }

    @Test
    func esrchIsReconciledWithBoundedTypedWaitStatesBeforeReap() async throws {
        let operations = POSIXOperationsSpy(
            [.interrupted, .stillRunning, .exited(4)],
            signalError: POSIXError(.ESRCH)
        )
        let process = try await POSIXProcessLauncher(operations).launch(.shutdownAllSimulators)

        try process.send(.kill)
        let completion = try await process.reap()

        #expect(completion.terminationStatus == 4)
        #expect(operations.waitRequests.count == 3)
    }

    @Test
    func argumentAllocationFailureFreesEveryPriorCStringAndReportsEnomem() {
        let allocator = CStringAllocatorFake(1)

        do {
            _ = try POSIXArgumentVector(["first", "second"], allocator: allocator)
            Issue.record("Expected argument allocation to fail.")
        } catch let error as POSIXError {
            #expect(error.code == .ENOMEM)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(allocator.allocationCount == 2)
        #expect(allocator.releaseCount == 1)
    }

    @Test
    func concurrentRestrictedSpawnsKeepLargeDescriptorStreamsIsolated() async throws {
        let operations = ConcurrentPOSIXOperationsFake()
        let launcher = POSIXProcessLauncher(operations)
        let deleteProcess = try await launcher.launch(.deleteUnavailableSimulators)
        let shutdownProcess = try await launcher.launch(.shutdownAllSimulators)
        let largeOutput = Data(repeating: 0x41, count: 2 * 1_024 * 1_024)
        operations.setDescriptorData([
            41: largeOutput,
            42: Data("delete-err".utf8),
            51: Data("shutdown-out".utf8),
            52: Data("shutdown-err".utf8)
        ])
        async let deleteCompletion = deleteProcess.reap()
        async let shutdownCompletion = shutdownProcess.reap()
        let (deleteResult, shutdownResult) = try await (deleteCompletion, shutdownCompletion)

        #expect(deleteResult.standardOutput == largeOutput)
        #expect(deleteResult.standardError == Data("delete-err".utf8))
        #expect(shutdownResult.standardOutput == Data("shutdown-out".utf8))
        #expect(shutdownResult.standardError == Data("shutdown-err".utf8))
        #expect(operations.readDescriptors.sorted() == [41, 42, 51, 52])
    }

    @Test
    func outputAtConfiguredLimitSucceedsIndependentlyForBothStreams() async throws {
        let operations = POSIXOperationsSpy(
            [.exited(0)],
            descriptorData: [
                41: Data("1234".utf8),
                42: Data("abc".utf8)
            ]
        )
        let launcher = POSIXProcessLauncher(
            operations,
            outputPolicy: .init(limitPerStream: 4)
        )

        let completion = try await launcher
            .launch(.shutdownAllSimulators)
            .reap()

        #expect(completion.standardOutput == Data("1234".utf8))
        #expect(completion.standardError == Data("abc".utf8))
    }

    @Test
    func outputOverLimitWhileAliveIsTerminatedAndReapedBeforeExecutorReturns() async {
        let operations = POSIXOperationsSpy(
            [.exited(137)],
            descriptorData: [
                41: Data("12345".utf8),
                42: Data()
            ],
            signalError: SignalError.expected
        )
        let launcher = POSIXProcessLauncher(
            operations,
            outputPolicy: .init(limitPerStream: 4)
        )
        let executor = XcrunProcessExecutor(
            launcher,
            supervisorClock: ImmediateMonotonicClock()
        )

        await #expect(
            throws: ProcessExecutionError.outputLimitExceeded(.standardOutput, 4)
        ) {
            try await executor.execute(
                .shutdownAllSimulators,
                timeout: .seconds(60)
            )
        }
        #expect(operations.signals == [.termination, .kill])
        #expect(operations.waitRequests == [
            .init(processIdentifier: 123, noHang: false)
        ])
        #expect(operations.closedDescriptors.sorted() == [41, 42])
        #expect(operations.readDescriptors == [41])
    }

    @Test
    func captureReadFailureAfterConfirmedReapDoesNotSignalOrReapAgain() async {
        let operations = POSIXOperationsSpy(
            [.exited(0)],
            readError: POSIXError(.EIO)
        )
        let executor = XcrunProcessExecutor(POSIXProcessLauncher(operations))

        await #expect(
            throws: ProcessExecutionError.captureFailed(
                .standardOutput,
                POSIXError(.EIO).localizedDescription
            )
        ) {
            try await executor.execute(
                .deleteUnavailableSimulators,
                timeout: .seconds(60)
            )
        }
        #expect(operations.signals.isEmpty)
        #expect(operations.waitRequests == [
            .init(processIdentifier: 123, noHang: true)
        ])
    }

    @Test(arguments: [
        POSIXWaitResult.failure(EIO),
        POSIXWaitResult.noChild
    ])
    func waitObservationFailureIsSupervisedUntilARealReap(
        _ firstWaitResult: POSIXWaitResult
    ) async {
        let operations = POSIXOperationsSpy([
            firstWaitResult,
            .exited(137)
        ])
        let executor = XcrunProcessExecutor(
            POSIXProcessLauncher(operations),
            supervisorClock: ImmediateMonotonicClock()
        )

        await #expect(throws: ProcessExecutionError.self) {
            try await executor.execute(
                .shutdownAllSimulators,
                timeout: .seconds(60)
            )
        }
        #expect(operations.signals.first == .termination)
        #expect(operations.waitRequests.count == 2)
        #expect(operations.readDescriptors.sorted() == [41, 42])
    }

    @Test
    func systemSpawnUsesUnlinkedExclusiveRegularCaptures() throws {
        let systemCalls = SpawnSystemCallsSpy()
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)
        let request = CleanupProcessSpawnRequest(
            arguments: ["/usr/bin/xcrun", "simctl", "shutdown", "all"],
            attributeFlags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT),
            environment: ["LANG=en_US.UTF-8"],
            executablePath: "/usr/bin/xcrun",
            standardErrorTarget: STDERR_FILENO,
            standardOutputTarget: STDOUT_FILENO
        )

        let child = try operations.spawn(request)

        #expect(child == .init(
            processIdentifier: 321,
            standardErrorDescriptor: 11,
            standardOutputDescriptor: 10
        ))
        #expect(systemCalls.openRequests.count == 2)
        #expect(systemCalls.openRequests.allSatisfy {
            $0.flags == O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC | O_NOFOLLOW
        })
        #expect(systemCalls.openRequests.allSatisfy {
            $0.mode == S_IRUSR | S_IWUSR
        })
        #expect(Set(systemCalls.openRequests.map(\.path)).count == 2)
        #expect(systemCalls.unlinkedPaths == systemCalls.openRequests.map(\.path))
        #expect(systemCalls.regularFileChecks == [0, 1])
        #expect(systemCalls.duplicationRequests == [
            .init(fileDescriptor: 0, minimum: 3),
            .init(fileDescriptor: 1, minimum: 3)
        ])
        #expect(systemCalls.spawnRequests == [
            POSIXKernelSpawnRequest(
                arguments: request.arguments,
                attributeFlags: request.attributeFlags,
                duplications: [
                    .init(source: 10, target: STDOUT_FILENO),
                    .init(source: 11, target: STDERR_FILENO)
                ],
                environment: request.environment,
                executablePath: request.executablePath
            )
        ])
        #expect(systemCalls.closedDescriptors == [0, 1])
    }

    @Test
    func systemSpawnFailureClosesEveryOwnedDescriptorAfterUnlinking() {
        let systemCalls = SpawnSystemCallsSpy(POSIXError(.EACCES))
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)
        let request = CleanupProcessSpawnRequest(
            arguments: ["/usr/bin/xcrun", "simctl", "shutdown", "all"],
            attributeFlags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT),
            environment: [],
            executablePath: "/usr/bin/xcrun",
            standardErrorTarget: STDERR_FILENO,
            standardOutputTarget: STDOUT_FILENO
        )

        #expect(throws: POSIXError.self) {
            try operations.spawn(request)
        }
        #expect(systemCalls.unlinkedPaths == systemCalls.openRequests.map(\.path))
        #expect(systemCalls.closedDescriptors == [0, 1, 11, 10])
    }

    @Test
    func unlinkFailureClosesRawDescriptorAndPreventsSpawn() {
        let systemCalls = SpawnSystemCallsSpy(
            unlinkError: POSIXError(.EACCES)
        )
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)
        let request = CleanupProcessSpawnRequest(
            arguments: ["/usr/bin/xcrun", "simctl", "shutdown", "all"],
            attributeFlags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT),
            environment: [],
            executablePath: "/usr/bin/xcrun",
            standardErrorTarget: STDERR_FILENO,
            standardOutputTarget: STDOUT_FILENO
        )

        #expect(throws: POSIXError.self) {
            try operations.spawn(request)
        }
        #expect(systemCalls.openRequests.count == 1)
        #expect(systemCalls.unlinkedPaths == systemCalls.openRequests.map(\.path))
        #expect(systemCalls.closedDescriptors == [0])
        #expect(systemCalls.duplicationRequests.isEmpty)
        #expect(systemCalls.spawnRequests.isEmpty)
    }

    @Test
    func openFailureDoesNotClaimOrCloseAnUnownedDescriptor() {
        let systemCalls = SpawnSystemCallsSpy(
            openError: POSIXError(.EACCES)
        )
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)
        let request = CleanupProcessSpawnRequest(
            arguments: ["/usr/bin/xcrun", "simctl", "shutdown", "all"],
            attributeFlags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT),
            environment: [],
            executablePath: "/usr/bin/xcrun",
            standardErrorTarget: STDERR_FILENO,
            standardOutputTarget: STDOUT_FILENO
        )

        #expect(throws: POSIXError.self) {
            try operations.spawn(request)
        }
        #expect(systemCalls.openRequests.count == 1)
        #expect(systemCalls.closedDescriptors.isEmpty)
        #expect(systemCalls.unlinkedPaths.isEmpty)
        #expect(systemCalls.spawnRequests.isEmpty)
    }

    @Test
    func nonRegularCaptureIsUnlinkedAndClosedWithoutSpawn() {
        let systemCalls = SpawnSystemCallsSpy(captureIsRegular: false)
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)
        let request = CleanupProcessSpawnRequest(
            arguments: ["/usr/bin/xcrun", "simctl", "shutdown", "all"],
            attributeFlags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT),
            environment: [],
            executablePath: "/usr/bin/xcrun",
            standardErrorTarget: STDERR_FILENO,
            standardOutputTarget: STDOUT_FILENO
        )

        #expect(throws: POSIXError.self) {
            try operations.spawn(request)
        }
        #expect(systemCalls.regularFileChecks == [0])
        #expect(systemCalls.closedDescriptors == [0])
        #expect(systemCalls.unlinkedPaths == systemCalls.openRequests.map(\.path))
        #expect(systemCalls.spawnRequests.isEmpty)
    }

    @Test
    func readRetriesInterruptionsAndAccumulatesPartialReadsAtStableOffsets() async throws {
        let systemCalls = SpawnSystemCallsSpy(
            reportedFileSizes: [6, 6],
            readResults: [
                .interrupted,
                .data(Data("abc".utf8)),
                .data(Data("def".utf8)),
                .endOfFile
            ]
        )
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)

        let data = try await operations.readToEnd(
            10,
            stream: .standardOutput,
            limit: 6
        )

        #expect(data == Data("abcdef".utf8))
        #expect(systemCalls.readRequests == [
            .init(fileDescriptor: 10, maximumLength: 6, offset: 0),
            .init(fileDescriptor: 10, maximumLength: 6, offset: 0),
            .init(fileDescriptor: 10, maximumLength: 3, offset: 3)
        ])
        #expect(systemCalls.closedDescriptors == [10])
    }

    @Test
    func readFailureStillClosesOwnedDescriptor() async {
        let systemCalls = SpawnSystemCallsSpy(
            reportedFileSizes: [100],
            readResults: [
                .data(Data("partial".utf8)),
                .failure(EIO)
            ]
        )
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)

        await #expect(throws: POSIXError.self) {
            try await operations.readToEnd(
                12,
                stream: .standardError,
                limit: 100
            )
        }
        #expect(systemCalls.closedDescriptors == [12])
    }

    @Test
    func hugeReportedCaptureSizeFailsBeforeReadOrAllocation() async {
        let systemCalls = SpawnSystemCallsSpy(
            reportedFileSizes: [Int64.max]
        )
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)

        await #expect(
            throws: ProcessExecutionError.outputLimitExceeded(.standardOutput, 8)
        ) {
            try await operations.readToEnd(
                10,
                stream: .standardOutput,
                limit: 8
            )
        }
        #expect(systemCalls.readRequests.isEmpty)
        #expect(systemCalls.closedDescriptors == [10])
    }

    @Test
    func negativeReportedCaptureSizeFailsBeforeReadOrAllocation() async {
        let systemCalls = SpawnSystemCallsSpy(
            reportedFileSizes: [-1]
        )
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)

        await #expect(
            throws: ProcessExecutionError.outputLimitExceeded(.standardError, 8)
        ) {
            try await operations.readToEnd(
                11,
                stream: .standardError,
                limit: 8
            )
        }
        #expect(systemCalls.readRequests.isEmpty)
        #expect(systemCalls.closedDescriptors == [11])
    }

    @Test
    func readPathRejectsAnInjectedOffsetOverflowAndClosesDescriptor() async {
        let systemCalls = SpawnSystemCallsSpy(
            offsetError: POSIXError(.EOVERFLOW),
            reportedFileSizes: [1],
            readResults: [.data(Data("x".utf8))]
        )
        let operations = SystemCleanupProcessPOSIXOperations(systemCalls)

        await #expect(throws: POSIXError.self) {
            try await operations.readToEnd(
                10,
                stream: .standardOutput,
                limit: 1
            )
        }
        #expect(systemCalls.readRequests.count == 1)
        #expect(systemCalls.closedDescriptors == [10])
    }

    @Test
    func productionCaptureIsAtomicRegularCloseOnExecAndImmediatelyUnlinkable() throws {
        let systemCalls = SystemCleanupProcessSpawnSystemCalls()
        let capturePath = FileManager.default.temporaryDirectory
            .appending(path: "CleanerXcode-test-\(UUID().uuidString).capture")
            .path
        let flags = O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC | O_NOFOLLOW
        let descriptor = try systemCalls.openCapture(
            capturePath,
            flags: flags,
            mode: S_IRUSR | S_IWUSR
        )

        defer {
            try? systemCalls.unlink(capturePath)
            systemCalls.close(descriptor)
        }

        let descriptorFlags = fcntl(descriptor, F_GETFD)
        #expect(descriptorFlags >= 0)
        #expect(descriptorFlags & FD_CLOEXEC == FD_CLOEXEC)
        #expect(try systemCalls.isRegularFile(descriptor))
        try systemCalls.unlink(capturePath)
        #expect(!FileManager.default.fileExists(atPath: capturePath))
    }
}

private enum SignalError: Error {
    case expected
}

private enum LaunchError: Error {
    case expected
}

private struct WaitRequest: Equatable {

    // MARK: - Public Properties

    let processIdentifier: pid_t
    let noHang: Bool
}

private struct DuplicationRequest: Equatable {

    // MARK: - Public Properties

    let fileDescriptor: Int32
    let minimum: Int32
}

private struct OpenCaptureRequest: Equatable {

    // MARK: - Public Properties

    let flags: Int32
    let mode: mode_t
    let path: String
}

private struct ReadRequest: Equatable {

    // MARK: - Public Properties

    let fileDescriptor: Int32
    let maximumLength: Int
    let offset: Int64
}

private final class SpawnSystemCallsSpy: CleanupProcessSpawnSystemCalls, @unchecked Sendable {

    // MARK: - Public Properties

    private(set) var closedDescriptors = [Int32]()
    private(set) var duplicationRequests = [DuplicationRequest]()
    private(set) var openRequests = [OpenCaptureRequest]()
    private(set) var readRequests = [ReadRequest]()
    private(set) var regularFileChecks = [Int32]()
    private(set) var spawnRequests = [POSIXKernelSpawnRequest]()
    private(set) var unlinkedPaths = [String]()

    // MARK: - Private Properties

    private var captureDescriptors: [Int32] = [0, 1]
    private let captureIsRegular: Bool
    private var duplicatedDescriptors: [Int32] = [10, 11]
    private let offsetError: Error?
    private let openError: Error?
    private var reportedFileSizes: [Int64]
    private var readResults: [POSIXReadResult]
    private let spawnError: Error?
    private let unlinkError: Error?

    // MARK: - Initializer

    init(
        _ spawnError: Error? = nil,
        captureIsRegular: Bool = true,
        offsetError: Error? = nil,
        openError: Error? = nil,
        reportedFileSizes: [Int64] = [],
        readResults: [POSIXReadResult] = [],
        unlinkError: Error? = nil
    ) {
        self.captureIsRegular = captureIsRegular
        self.offsetError = offsetError
        self.openError = openError
        self.reportedFileSizes = reportedFileSizes
        self.readResults = readResults
        self.spawnError = spawnError
        self.unlinkError = unlinkError
    }

    // MARK: - Public Methods

    func advanceReadOffset(_ offset: Int64, count: Int) throws -> Int64 {
        if let offsetError {
            throw offsetError
        }

        return offset + Int64(count)
    }

    func close(_ fileDescriptor: Int32) {
        closedDescriptors.append(fileDescriptor)
    }

    func duplicateCloseOnExec(_ fileDescriptor: Int32, minimum: Int32) throws -> Int32 {
        duplicationRequests.append(.init(
            fileDescriptor: fileDescriptor,
            minimum: minimum
        ))
        return duplicatedDescriptors.removeFirst()
    }

    func fileSize(_ fileDescriptor: Int32) throws -> Int64 {
        reportedFileSizes.isEmpty ? 0 : reportedFileSizes.removeFirst()
    }

    func isRegularFile(_ fileDescriptor: Int32) throws -> Bool {
        regularFileChecks.append(fileDescriptor)

        return captureIsRegular
    }

    func openCapture(_ path: String, flags: Int32, mode: mode_t) throws -> Int32 {
        openRequests.append(.init(
            flags: flags,
            mode: mode,
            path: path
        ))

        if let openError {
            throw openError
        }

        return captureDescriptors.removeFirst()
    }

    func read(_ fileDescriptor: Int32, offset: Int64, maximumLength: Int) -> POSIXReadResult {
        readRequests.append(.init(
            fileDescriptor: fileDescriptor,
            maximumLength: maximumLength,
            offset: offset
        ))

        return readResults.isEmpty ? .endOfFile : readResults.removeFirst()
    }

    func spawn(_ request: POSIXKernelSpawnRequest) throws -> pid_t {
        spawnRequests.append(request)

        if let spawnError {
            throw spawnError
        }

        return 321
    }

    func unlink(_ path: String) throws {
        unlinkedPaths.append(path)

        if let unlinkError {
            throw unlinkError
        }
    }
}

private final class POSIXOperationsSpy: CleanupProcessPOSIXOperations, @unchecked Sendable {

    // MARK: - Public Properties

    var closedDescriptors: [Int32] {
        lock.withLock { storedClosedDescriptors }
    }

    var readDescriptors: [Int32] {
        lock.withLock { storedReadDescriptors }
    }

    var spawnRequests: [CleanupProcessSpawnRequest] {
        lock.withLock { storedSpawnRequests }
    }

    var signals: [ChildProcessSignal] {
        lock.withLock { storedSignals }
    }

    var waitRequests: [WaitRequest] {
        lock.withLock { storedWaitRequests }
    }

    // MARK: - Private Properties

    private let descriptorData: [Int32: Data]
    private let fileSizes: [Int32: Int64]
    private let lock = NSLock()
    private let readError: Error?
    private let signalError: Error?
    private var storedClosedDescriptors = [Int32]()
    private var storedReadDescriptors = [Int32]()
    private var storedSpawnRequests = [CleanupProcessSpawnRequest]()
    private var storedSignals = [ChildProcessSignal]()
    private var storedWaitRequests = [WaitRequest]()
    private var waitResults: [POSIXWaitResult]

    // MARK: - Initializer

    init(
        _ waitResults: [POSIXWaitResult],
        descriptorData: [Int32: Data] = [:],
        fileSizes: [Int32: Int64] = [:],
        readError: Error? = nil,
        signalError: Error? = nil
    ) {
        self.waitResults = waitResults
        self.descriptorData = descriptorData
        self.fileSizes = fileSizes
        self.readError = readError
        self.signalError = signalError
    }

    // MARK: - Public Methods

    func close(_ fileDescriptor: Int32) {
        lock.withLock {
            storedClosedDescriptors.append(fileDescriptor)
        }
    }

    func fileSize(_ fileDescriptor: Int32) throws -> Int64 {
        fileSizes[fileDescriptor] ?? Int64(descriptorData[fileDescriptor]?.count ?? 0)
    }

    func readToEnd(
        _ fileDescriptor: Int32,
        stream: ProcessOutputStream,
        limit: Int64
    ) async throws -> Data {
        lock.withLock {
            storedClosedDescriptors.append(fileDescriptor)
            storedReadDescriptors.append(fileDescriptor)
        }

        if let readError {
            throw readError
        }

        let data = descriptorData[fileDescriptor] ?? Data()

        guard Int64(data.count) <= limit else {
            throw ProcessExecutionError.outputLimitExceeded(stream, limit)
        }

        return data
    }

    func send(_ signal: ChildProcessSignal, to processIdentifier: pid_t) throws {
        lock.withLock {
            storedSignals.append(signal)
        }

        if let signalError {
            throw signalError
        }
    }

    func spawn(_ request: CleanupProcessSpawnRequest) throws -> SpawnedCleanupProcess {
        lock.withLock {
            storedSpawnRequests.append(request)
        }
        return SpawnedCleanupProcess(
            processIdentifier: 123,
            standardErrorDescriptor: 42,
            standardOutputDescriptor: 41
        )
    }

    func wait(_ processIdentifier: pid_t, noHang: Bool) -> POSIXWaitResult {
        lock.withLock {
            storedWaitRequests.append(.init(
                processIdentifier: processIdentifier,
                noHang: noHang
            ))
            return waitResults.isEmpty ? .stillRunning : waitResults.removeFirst()
        }
    }
}

private final class ConcurrentPOSIXOperationsFake: CleanupProcessPOSIXOperations, @unchecked Sendable {

    // MARK: - Public Properties

    var readDescriptors: [Int32] {
        lock.withLock { storedReadDescriptors }
    }

    // MARK: - Private Properties

    private var descriptorData = [Int32: Data]()
    private let lock = NSLock()
    private var storedReadDescriptors = [Int32]()

    // MARK: - Public Methods

    func close(_ fileDescriptor: Int32) {}

    func fileSize(_ fileDescriptor: Int32) throws -> Int64 {
        lock.withLock {
            Int64(descriptorData[fileDescriptor]?.count ?? 0)
        }
    }

    func readToEnd(
        _ fileDescriptor: Int32,
        stream: ProcessOutputStream,
        limit: Int64
    ) async throws -> Data {
        lock.withLock {
            storedReadDescriptors.append(fileDescriptor)
            return descriptorData[fileDescriptor] ?? Data()
        }
    }

    func send(_ signal: ChildProcessSignal, to processIdentifier: pid_t) throws {}

    func setDescriptorData(_ data: [Int32: Data]) {
        lock.withLock {
            descriptorData = data
        }
    }

    func spawn(_ request: CleanupProcessSpawnRequest) throws -> SpawnedCleanupProcess {
        if request.arguments.contains("delete") {
            return .init(
                processIdentifier: 1,
                standardErrorDescriptor: 42,
                standardOutputDescriptor: 41
            )
        }

        return .init(
            processIdentifier: 2,
            standardErrorDescriptor: 52,
            standardOutputDescriptor: 51
        )
    }

    func wait(_ processIdentifier: pid_t, noHang: Bool) -> POSIXWaitResult {
        .exited(0)
    }
}

private final class CStringAllocatorFake: CStringAllocating {

    // MARK: - Public Properties

    private(set) var allocationCount = 0
    private(set) var releaseCount = 0

    // MARK: - Private Properties

    private let successfulAllocations: Int

    // MARK: - Initializer

    init(_ successfulAllocations: Int) {
        self.successfulAllocations = successfulAllocations
    }

    // MARK: - Public Methods

    func allocate(_ string: String) -> UnsafeMutablePointer<CChar>? {
        allocationCount += 1

        guard allocationCount <= successfulAllocations else {
            return nil
        }

        return strdup(string)
    }

    func release(_ pointer: UnsafeMutablePointer<CChar>) {
        releaseCount += 1
        free(pointer)
    }
}

private struct FailingProcessLauncher: ProcessLaunching {

    // MARK: - Public Methods

    func launch(_ operation: XcrunOperation) async throws -> any RunningProcess {
        throw LaunchError.expected
    }
}

private final class CompletionProbe: @unchecked Sendable {

    // MARK: - Public Properties

    var isComplete: Bool {
        lock.withLock { storedIsComplete }
    }

    // MARK: - Private Properties

    private let lock = NSLock()
    private var storedIsComplete = false

    // MARK: - Public Methods

    func complete() {
        lock.withLock {
            storedIsComplete = true
        }
    }
}

private final class ProcessLauncherSpy: ProcessLaunching, @unchecked Sendable {

    // MARK: - Public Properties

    var launchCount: Int {
        lock.withLock { storedOperations.count }
    }

    var operations: [XcrunOperation] {
        lock.withLock { storedOperations }
    }

    // MARK: - Private Properties

    private let launchStream = AsyncStream<Void>.makeStream()
    private let lock = NSLock()
    private let process: any RunningProcess
    private var storedOperations = [XcrunOperation]()

    // MARK: - Initializer

    init(_ process: any RunningProcess) {
        self.process = process
    }

    // MARK: - Public Methods

    func launch(_ operation: XcrunOperation) async throws -> any RunningProcess {
        lock.withLock {
            storedOperations.append(operation)
        }
        launchStream.continuation.yield()
        return process
    }

    func waitUntilLaunched() async {
        if launchCount > 0 {
            return
        }

        var iterator = launchStream.stream.makeAsyncIterator()
        _ = await iterator.next()
    }
}

private final class RunningProcessFake: RunningProcess, @unchecked Sendable {

    // MARK: - Public Properties

    var observerCount: Int {
        lock.withLock { observers.count }
    }

    var reapCount: Int {
        lock.withLock { storedReapCount }
    }

    var signals: [ChildProcessSignal] {
        lock.withLock { storedSignals }
    }

    // MARK: - Private Properties

    private let killCompletion: ProcessCompletion?
    private let killError: Error?
    private let lock = NSLock()
    private let observationError: Error?
    private let terminationCompletion: ProcessCompletion?
    private let terminationError: Error?
    private var exitCompletion: ProcessCompletion?
    private var observers = [UUID: CheckedContinuation<ProcessCompletion, Error>]()
    private var reapWaiters = [CheckedContinuation<ProcessCompletion, Never>]()
    private var signalWaiters = [(Int, CheckedContinuation<Void, Never>)]()
    private var storedReapCount = 0
    private var storedSignals = [ChildProcessSignal]()

    // MARK: - Initializer

    init(
        _ completion: ProcessCompletion? = nil,
        terminationCompletion: ProcessCompletion? = nil,
        killCompletion: ProcessCompletion? = nil,
        observationError: Error? = nil,
        terminationError: Error? = nil,
        killError: Error? = nil
    ) {
        exitCompletion = completion
        self.terminationCompletion = terminationCompletion
        self.killCompletion = killCompletion
        self.observationError = observationError
        self.terminationError = terminationError
        self.killError = killError
    }

    // MARK: - Public Methods

    func observeExit() async throws -> ProcessCompletion {
        if let observationError {
            throw observationError
        }

        let completion = try await waitForExitCancellably()
        return finishReap(completion)
    }

    func reap() async throws -> ProcessCompletion {
        let completion = await withCheckedContinuation { continuation in
            let immediateCompletion: ProcessCompletion? = lock.withLock {
                if let exitCompletion {
                    return exitCompletion
                }

                reapWaiters.append(continuation)
                return nil
            }

            if let immediateCompletion {
                continuation.resume(returning: immediateCompletion)
            }
        }

        return finishReap(completion)
    }

    func release(_ completion: ProcessCompletion) {
        let resumptions = lock.withLock {
            exitCompletion = completion
            let observers = Array(observers.values)
            let reapWaiters = reapWaiters
            self.observers.removeAll()
            self.reapWaiters.removeAll()
            return (observers, reapWaiters)
        }
        resumptions.0.forEach { $0.resume(returning: completion) }
        resumptions.1.forEach { $0.resume(returning: completion) }
    }

    func send(_ signal: ChildProcessSignal) throws {
        let signalResult: (Result<ProcessCompletion?, Error>, [CheckedContinuation<Void, Never>]) = lock.withLock {
            storedSignals.append(signal)
            let resumptions = takeReadySignalWaiters()
            let error = signal == .termination ? terminationError : killError

            if let error {
                return (.failure(error), resumptions)
            }

            let completion = signal == .termination ? terminationCompletion : killCompletion
            return (.success(completion), resumptions)
        }
        signalResult.1.forEach { $0.resume() }

        if let completion = try signalResult.0.get() {
            release(completion)
        }
    }

    func waitForSignalCount(_ count: Int) async {
        if signals.count >= count {
            return
        }

        await withCheckedContinuation { continuation in
            var resumptions = [CheckedContinuation<Void, Never>]()

            lock.withLock {
                signalWaiters.append((count, continuation))
                resumptions = takeReadySignalWaiters()
            }
            resumptions.forEach { $0.resume() }
        }
    }

    // MARK: - Private Methods

    private func cancelObserver(_ identifier: UUID) {
        let continuation = lock.withLock {
            observers.removeValue(forKey: identifier)
        }
        continuation?.resume(throwing: CancellationError())
    }

    private func finishReap(_ completion: ProcessCompletion) -> ProcessCompletion {
        lock.withLock {
            if storedReapCount == 0 {
                storedReapCount = 1
            }
        }

        return completion
    }

    private func takeReadySignalWaiters() -> [CheckedContinuation<Void, Never>] {
        let readyWaiters = signalWaiters.filter { storedSignals.count >= $0.0 }
        signalWaiters.removeAll { storedSignals.count >= $0.0 }
        return readyWaiters.map(\.1)
    }

    private func waitForExitCancellably() async throws -> ProcessCompletion {
        let identifier = UUID()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let result: Result<ProcessCompletion, Error>? = lock.withLock {
                    if let exitCompletion {
                        return .success(exitCompletion)
                    }

                    guard !Task.isCancelled else {
                        return .failure(CancellationError())
                    }

                    observers[identifier] = continuation
                    return nil
                }

                if let result {
                    continuation.resume(with: result)
                }
            }
        } onCancel: {
            cancelObserver(identifier)
        }
    }
}

private final class ImmediateMonotonicClock: MonotonicClock, @unchecked Sendable {

    // MARK: - Private Properties

    private let lock = NSLock()
    private var instant = Duration.zero

    // MARK: - Public Methods

    func now() -> Duration {
        lock.withLock { instant }
    }

    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        lock.withLock {
            instant += duration
        }
    }
}

private struct SuspendingMonotonicClock: MonotonicClock {

    // MARK: - Public Methods

    func now() -> Duration {
        .zero
    }

    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: .milliseconds(50))
    }
}

private final class ProcessExecutorSpy: XcrunExecuting, @unchecked Sendable {

    // MARK: - Public Properties

    private(set) var operations = [XcrunOperation]()

    // MARK: - Public Methods

    func execute(_ operation: XcrunOperation, timeout: Duration) async throws -> ProcessExecutionResult {
        operations.append(operation)
        return .init(standardOutput: "", standardError: "", terminationStatus: 0)
    }
}
