import Darwin
import Foundation

enum XcrunOperation: CaseIterable, Equatable, Sendable {
    case deleteUnavailableSimulators
    case shutdownAllSimulators

    // MARK: - Public Properties

    var arguments: [String] {
        switch self {
        case .deleteUnavailableSimulators:
            ["simctl", "delete", "unavailable"]
        case .shutdownAllSimulators:
            ["simctl", "shutdown", "all"]
        }
    }
}

struct ProcessCompletion: Equatable, Sendable {

    // MARK: - Public Properties

    let standardOutput: Data
    let standardError: Data
    let terminationStatus: Int32
}

struct ProcessExecutionResult: Equatable, Sendable {

    // MARK: - Public Properties

    let standardOutput: String
    let standardError: String
    let terminationStatus: Int32
}

enum ProcessOutputStream: Equatable, Sendable {
    case standardError
    case standardOutput
}

struct ProcessOutputPolicy: Equatable, Sendable {

    // MARK: - Public Properties

    static let defaultLimitPerStream = Int64(8 * 1_024 * 1_024)

    let limitPerStream: Int64

    // MARK: - Initializer

    init(limitPerStream: Int64 = Self.defaultLimitPerStream) {
        precondition(limitPerStream >= 0)
        self.limitPerStream = limitPerStream
    }
}

enum ChildProcessSignal: Equatable, Sendable {
    case kill
    case termination
}

enum ProcessExecutionError: Error, Equatable, LocalizedError, Sendable {
    case cancelled
    case captureFailed(ProcessOutputStream, String)
    case launchFailed(String)
    case lifecycleFailed(String)
    case nonzeroExit(ProcessExecutionResult)
    case outputLimitExceeded(ProcessOutputStream, Int64)
    case signalFailed(ChildProcessSignal, String)
    case timeout

    // MARK: - Public Properties

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "The process was cancelled."
        case .captureFailed(let stream, let message):
            "Reading \(stream) after process exit failed: \(message)"
        case .launchFailed(let message):
            "The process could not be launched: \(message)"
        case .lifecycleFailed(let message):
            "The process lifecycle failed: \(message)"
        case .nonzeroExit(let result):
            "The process exited with status \(result.terminationStatus): \(result.standardError)"
        case .outputLimitExceeded(let stream, let limit):
            "The \(stream) output exceeded the \(limit)-byte limit."
        case .signalFailed(let signal, let message):
            "The \(signal) signal failed: \(message)"
        case .timeout:
            "The process exceeded its execution timeout."
        }
    }
}

protocol XcrunExecuting: Sendable {
    func execute(_ operation: XcrunOperation, timeout: Duration) async throws -> ProcessExecutionResult
}

protocol ProcessLaunching: Sendable {
    func launch(_ operation: XcrunOperation) async throws -> any RunningProcess
}

protocol RunningProcess: Sendable {
    func observeExit() async throws -> ProcessCompletion
    func reap() async throws -> ProcessCompletion
    func send(_ signal: ChildProcessSignal) throws
}

private protocol ReapedProcessError: Error {
    var executionErrorIfReaped: ProcessExecutionError? { get }
}

private struct SupervisedProcessError: ReapedProcessError {

    // MARK: - Public Properties

    let executionErrorIfReaped: ProcessExecutionError?

    // MARK: - Initializer

    init(_ executionError: ProcessExecutionError) {
        executionErrorIfReaped = executionError
    }
}

struct XcrunProcessExecutor: XcrunExecuting, Sendable {

    // MARK: - Private Properties

    private let launcher: any ProcessLaunching
    private let supervisor: ProcessTerminationSupervisor
    private let timeoutClock: any MonotonicClock

    // MARK: - Initializer

    init(
        _ launcher: any ProcessLaunching = POSIXProcessLauncher(),
        timeoutClock: any MonotonicClock = ContinuousMonotonicClock(),
        supervisorClock: any MonotonicClock = ContinuousMonotonicClock()
    ) {
        self.launcher = launcher
        supervisor = .init(supervisorClock)
        self.timeoutClock = timeoutClock
    }

    // MARK: - Public Methods

    func execute(_ operation: XcrunOperation, timeout: Duration) async throws -> ProcessExecutionResult {
        do {
            try Task.checkCancellation()
        } catch {
            throw ProcessExecutionError.cancelled
        }

        let process: any RunningProcess

        do {
            process = try await launcher.launch(operation)
        } catch {
            if error is CancellationError {
                throw ProcessExecutionError.cancelled
            }

            throw ProcessExecutionError.launchFailed(error.localizedDescription)
        }

        let completion: ProcessCompletion

        do {
            switch try await ProcessExitRace(timeoutClock).run(process, deadline: timeout) {
            case .completion(let processCompletion):
                completion = processCompletion
            case .deadline:
                let cleanup = await supervise(process)
                let reason: ProcessExecutionError = Task.isCancelled ? .cancelled : .timeout
                throw SupervisedProcessError(resolve(reason, cleanup: cleanup))
            }
        } catch {
            if let reapedError = error as? any ReapedProcessError,
               let executionError = reapedError.executionErrorIfReaped {
                throw executionError
            }

            let cleanup = await supervise(process)
            let reason: ProcessExecutionError

            if error is CancellationError {
                reason = .cancelled
            } else if let executionError = error as? ProcessExecutionError {
                reason = executionError
            } else {
                reason = .lifecycleFailed(error.localizedDescription)
            }

            throw resolve(reason, cleanup: cleanup)
        }

        if Task.isCancelled {
            let cleanup = await supervise(process)
            throw resolve(.cancelled, cleanup: cleanup)
        }

        let result = ProcessExecutionResult(
            standardOutput: String(decoding: completion.standardOutput, as: UTF8.self),
            standardError: String(decoding: completion.standardError, as: UTF8.self),
            terminationStatus: completion.terminationStatus
        )

        guard result.terminationStatus == 0 else {
            throw ProcessExecutionError.nonzeroExit(result)
        }

        return result
    }

    // MARK: - Private Methods

    private func supervise(_ process: any RunningProcess) async -> ProcessTerminationCleanup {
        await Task.detached { [supervisor] in
            await supervisor.terminateAndReap(process)
        }.value
    }

    private func resolve(
        _ reason: ProcessExecutionError,
        cleanup: ProcessTerminationCleanup
    ) -> ProcessExecutionError {
        guard cleanup.reapConfirmed else {
            return cleanup.ownershipError
                ?? .lifecycleFailed("Process ownership ended without a confirmed reap.")
        }

        switch reason {
        case .cancelled, .outputLimitExceeded:
            return reason
        case .timeout:
            return cleanup.signalError ?? reason
        case .captureFailed:
            return cleanup.postReapError ?? reason
        case .launchFailed, .lifecycleFailed, .nonzeroExit, .signalFailed:
            return reason
        }
    }
}

private enum ProcessExitRaceResult: Sendable {
    case completion(ProcessCompletion)
    case deadline
}

private struct ProcessExitRace: Sendable {

    // MARK: - Private Properties

    private let clock: any MonotonicClock

    // MARK: - Initializer

    init(_ clock: any MonotonicClock) {
        self.clock = clock
    }

    // MARK: - Public Methods

    func run(
        _ process: any RunningProcess,
        deadline: Duration
    ) async throws -> ProcessExitRaceResult {
        try await withThrowingTaskGroup(of: ProcessExitRaceResult.self) { group in
            group.addTask {
                .completion(try await process.observeExit())
            }
            group.addTask { [clock] in
                try await clock.sleep(for: deadline)
                return .deadline
            }

            let firstResult: ProcessExitRaceResult

            do {
                guard let result = try await group.next() else {
                    throw CancellationError()
                }

                firstResult = result
            } catch {
                group.cancelAll()

                do {
                    while let _ = try await group.next() {}
                } catch {}

                throw error
            }

            group.cancelAll()

            do {
                while let _ = try await group.next() {}
            } catch is CancellationError {}

            return firstResult
        }
    }
}

struct ProcessTerminationCleanup: Sendable {

    // MARK: - Public Properties

    let completion: ProcessCompletion?
    let ownershipError: ProcessExecutionError?
    let postReapError: ProcessExecutionError?
    let reapConfirmed: Bool
    let signalError: ProcessExecutionError?
}

struct ProcessTerminationSupervisor: Sendable {

    // MARK: - Private Properties

    private let clock: any MonotonicClock
    private let gracePeriod: Duration

    // MARK: - Initializer

    init(
        _ clock: any MonotonicClock,
        gracePeriod: Duration = .seconds(1)
    ) {
        self.clock = clock
        self.gracePeriod = gracePeriod
    }

    // MARK: - Public Methods

    func terminateAndReap(_ process: any RunningProcess) async -> ProcessTerminationCleanup {
        var firstSignalError: ProcessExecutionError?

        do {
            try process.send(.termination)
        } catch {
            firstSignalError = .signalFailed(.termination, error.localizedDescription)
        }

        if !Task.isCancelled {
            do {
                let result = try await ProcessExitRace(clock).run(process, deadline: gracePeriod)

                if case .completion(let completion) = result {
                    return ProcessTerminationCleanup(
                        completion: completion,
                        ownershipError: nil,
                        postReapError: nil,
                        reapConfirmed: true,
                        signalError: firstSignalError
                    )
                }
            } catch {
                if let postReapError = confirmedReapError(error) {
                    return ProcessTerminationCleanup(
                        completion: nil,
                        ownershipError: nil,
                        postReapError: postReapError,
                        reapConfirmed: true,
                        signalError: firstSignalError
                    )
                }
            }
        }

        do {
            try process.send(.kill)
        } catch {
            if firstSignalError == nil {
                firstSignalError = .signalFailed(.kill, error.localizedDescription)
            }
        }

        do {
            let completion = try await process.reap()
            return ProcessTerminationCleanup(
                completion: completion,
                ownershipError: nil,
                postReapError: nil,
                reapConfirmed: true,
                signalError: firstSignalError
            )
        } catch {
            if let postReapError = confirmedReapError(error) {
                return ProcessTerminationCleanup(
                    completion: nil,
                    ownershipError: nil,
                    postReapError: postReapError,
                    reapConfirmed: true,
                    signalError: firstSignalError
                )
            }

            return ProcessTerminationCleanup(
                completion: nil,
                ownershipError: .lifecycleFailed(error.localizedDescription),
                postReapError: nil,
                reapConfirmed: false,
                signalError: firstSignalError
            )
        }
    }

    // MARK: - Private Methods

    private func confirmedReapError(_ error: any Error) -> ProcessExecutionError? {
        guard let reapedError = error as? any ReapedProcessError else {
            return nil
        }

        return reapedError.executionErrorIfReaped
    }
}

struct CleanupProcessSpawnRequest: Equatable, Sendable {

    // MARK: - Public Properties

    let arguments: [String]
    let attributeFlags: Int16
    let environment: [String]
    let executablePath: String
    let standardErrorTarget: Int32
    let standardOutputTarget: Int32
}

struct SpawnedCleanupProcess: Equatable, Sendable {

    // MARK: - Public Properties

    let processIdentifier: pid_t
    let standardErrorDescriptor: Int32
    let standardOutputDescriptor: Int32
}

enum POSIXWaitResult: Equatable, Sendable {
    case exited(Int32)
    case failure(Int32)
    case interrupted
    case noChild
    case signaled(Int32)
    case stillRunning
}

protocol CleanupProcessPOSIXOperations: Sendable {
    func close(_ fileDescriptor: Int32)
    func fileSize(_ fileDescriptor: Int32) throws -> Int64
    func readToEnd(
        _ fileDescriptor: Int32,
        stream: ProcessOutputStream,
        limit: Int64
    ) async throws -> Data
    func send(_ signal: ChildProcessSignal, to processIdentifier: pid_t) throws
    func spawn(_ request: CleanupProcessSpawnRequest) throws -> SpawnedCleanupProcess
    func wait(_ processIdentifier: pid_t, noHang: Bool) -> POSIXWaitResult
}

struct POSIXProcessLauncher: ProcessLaunching {

    // MARK: - Private Properties

    private let operations: any CleanupProcessPOSIXOperations
    private let outputPolicy: ProcessOutputPolicy

    // MARK: - Initializer

    init(
        _ operations: any CleanupProcessPOSIXOperations = SystemCleanupProcessPOSIXOperations(),
        outputPolicy: ProcessOutputPolicy = .init()
    ) {
        self.operations = operations
        self.outputPolicy = outputPolicy
    }

    // MARK: - Public Methods

    func launch(_ operation: XcrunOperation) async throws -> any RunningProcess {
        let request = CleanupProcessSpawnRequest(
            arguments: ["/usr/bin/xcrun"] + operation.arguments,
            attributeFlags: Int16(POSIX_SPAWN_CLOEXEC_DEFAULT),
            environment: ProcessInfo.processInfo.environment
                .map { "\($0.key)=\($0.value)" }
                .sorted(),
            executablePath: "/usr/bin/xcrun",
            standardErrorTarget: STDERR_FILENO,
            standardOutputTarget: STDOUT_FILENO
        )
        let child = try operations.spawn(request)
        return POSIXRunningProcess(
            child,
            operations: operations,
            outputPolicy: outputPolicy
        )
    }
}

enum POSIXLifecycleError: Error, LocalizedError, ReapedProcessError {
    case captureReadFailed(ProcessOutputStream, String)
    case invariant(String)
    case reapedOutputLimitExceeded(ProcessOutputStream, Int64)
    case waitFailed(Int32)

    // MARK: - Public Properties

    var errorDescription: String? {
        switch self {
        case .captureReadFailed(let stream, let message):
            "Reading \(stream) after reap failed: \(message)"
        case .invariant(let message):
            message
        case .reapedOutputLimitExceeded(let stream, let limit):
            "The reaped process exceeded the \(limit)-byte limit for \(stream)."
        case .waitFailed(let errorCode):
            "waitpid failed with errno \(errorCode)."
        }
    }

    var executionErrorIfReaped: ProcessExecutionError? {
        switch self {
        case .captureReadFailed(let stream, let message):
            .captureFailed(stream, message)
        case .reapedOutputLimitExceeded(let stream, let limit):
            .outputLimitExceeded(stream, limit)
        case .invariant, .waitFailed:
            nil
        }
    }
}

private final class POSIXRunningProcess: RunningProcess, @unchecked Sendable {

    // MARK: - Private Properties

    private enum State {
        case observed(Int32)
        case reaped(ProcessCompletion)
        case running
    }

    private let child: SpawnedCleanupProcess
    private let lock = NSLock()
    private let operations: any CleanupProcessPOSIXOperations
    private let outputPolicy: ProcessOutputPolicy
    private let standardErrorDrain: FileDescriptorDrain
    private let standardOutputDrain: FileDescriptorDrain
    private var state = State.running

    // MARK: - Initializer

    init(
        _ child: SpawnedCleanupProcess,
        operations: any CleanupProcessPOSIXOperations,
        outputPolicy: ProcessOutputPolicy
    ) {
        self.child = child
        self.operations = operations
        self.outputPolicy = outputPolicy
        standardOutputDrain = FileDescriptorDrain(
            child.standardOutputDescriptor,
            operations: operations,
            stream: .standardOutput
        )
        standardErrorDrain = FileDescriptorDrain(
            child.standardErrorDescriptor,
            operations: operations,
            stream: .standardError
        )
    }

    // MARK: - Public Methods

    func observeExit() async throws -> ProcessCompletion {
        while true {
            try Task.checkCancellation()
            try validateOutputSizes()

            if let completion = try await pollForExit() {
                return completion
            }

            try await ContinuousClock().sleep(for: .milliseconds(20))
        }
    }

    func reap() async throws -> ProcessCompletion {
        let existingStatus: Int32? = lock.withLock {
            guard case .observed(let status) = state else {
                return nil
            }

            return status
        }

        if let existingStatus {
            return try await finalizeReap(existingStatus)
        }

        if let completion = lock.withLock({ () -> ProcessCompletion? in
            guard case .reaped(let completion) = state else {
                return nil
            }

            return completion
        }) {
            return completion
        }

        let status = try await withThrowingTaskGroup(of: Int32.self) { group in
            group.addTask { [operations, child] in
                while true {
                    switch operations.wait(child.processIdentifier, noHang: false) {
                    case .exited(let status):
                        return status
                    case .signaled(let signal):
                        return 128 + signal
                    case .interrupted:
                        continue
                    case .failure(let errorCode):
                        throw POSIXLifecycleError.waitFailed(errorCode)
                    case .noChild:
                        throw POSIXLifecycleError.invariant(
                            "waitpid reported ECHILD before this backend recorded a reap."
                        )
                    case .stillRunning:
                        throw POSIXLifecycleError.invariant(
                            "Blocking waitpid unexpectedly reported a running child."
                        )
                    }
                }
            }

            guard let status = try await group.next() else {
                throw POSIXLifecycleError.invariant("The reap task produced no result.")
            }

            return status
        }

        return try await finalizeReap(status)
    }

    func send(_ signal: ChildProcessSignal) throws {
        let shouldSignal = lock.withLock {
            guard case .running = state else {
                return false
            }

            return true
        }

        guard shouldSignal else {
            return
        }

        do {
            try operations.send(signal, to: child.processIdentifier)
        } catch let error as POSIXError where error.code == .ESRCH {
            try reconcileMissingProcess()
        }
    }

    // MARK: - Private Methods

    private func finalizeReap(_ status: Int32) async throws -> ProcessCompletion {
        let standardOutput: Data
        let standardError: Data

        do {
            standardOutput = try await standardOutputDrain.data(limit: outputPolicy.limitPerStream)
        } catch let error as ProcessExecutionError {
            if case .outputLimitExceeded(let stream, let limit) = error {
                throw POSIXLifecycleError.reapedOutputLimitExceeded(stream, limit)
            }

            throw POSIXLifecycleError.captureReadFailed(.standardOutput, error.localizedDescription)
        } catch {
            throw POSIXLifecycleError.captureReadFailed(.standardOutput, error.localizedDescription)
        }

        do {
            standardError = try await standardErrorDrain.data(limit: outputPolicy.limitPerStream)
        } catch let error as ProcessExecutionError {
            if case .outputLimitExceeded(let stream, let limit) = error {
                throw POSIXLifecycleError.reapedOutputLimitExceeded(stream, limit)
            }

            throw POSIXLifecycleError.captureReadFailed(.standardError, error.localizedDescription)
        } catch {
            throw POSIXLifecycleError.captureReadFailed(.standardError, error.localizedDescription)
        }

        let completion = ProcessCompletion(
            standardOutput: standardOutput,
            standardError: standardError,
            terminationStatus: status
        )

        return lock.withLock {
            if case .reaped(let existingCompletion) = state {
                return existingCompletion
            }

            state = .reaped(completion)
            return completion
        }
    }

    private func pollForExit() async throws -> ProcessCompletion? {
        if let completion = lock.withLock({ () -> ProcessCompletion? in
            guard case .reaped(let completion) = state else {
                return nil
            }

            return completion
        }) {
            return completion
        }

        let result = operations.wait(child.processIdentifier, noHang: true)

        switch result {
        case .exited(let status):
            return try await recordAndFinalize(status)
        case .signaled(let signal):
            return try await recordAndFinalize(128 + signal)
        case .interrupted, .stillRunning:
            return nil
        case .failure(let errorCode):
            throw POSIXLifecycleError.waitFailed(errorCode)
        case .noChild:
            throw POSIXLifecycleError.invariant(
                "waitpid reported ECHILD before this backend recorded a reap."
            )
        }
    }

    private func reconcileMissingProcess() throws {
        var attempts = 0

        while attempts < 3 {
            switch operations.wait(child.processIdentifier, noHang: true) {
            case .exited(let status):
                lock.withLock {
                    state = .observed(status)
                }
                return
            case .signaled(let signal):
                lock.withLock {
                    state = .observed(128 + signal)
                }
                return
            case .interrupted:
                continue
            case .stillRunning:
                attempts += 1
                continue
            case .failure(let errorCode):
                throw POSIXLifecycleError.waitFailed(errorCode)
            case .noChild:
                throw POSIXLifecycleError.invariant(
                    "ESRCH reconciliation found ECHILD without an internal reap record."
                )
            }
        }

        throw POSIXError(.ESRCH)
    }

    private func recordAndFinalize(_ status: Int32) async throws -> ProcessCompletion {
        lock.withLock {
            state = .observed(status)
        }
        return try await finalizeReap(status)
    }

    private func validateOutputSizes() throws {
        try validateOutputSize(
            child.standardOutputDescriptor,
            stream: .standardOutput
        )
        try validateOutputSize(
            child.standardErrorDescriptor,
            stream: .standardError
        )
    }

    private func validateOutputSize(
        _ fileDescriptor: Int32,
        stream: ProcessOutputStream
    ) throws {
        let size = try operations.fileSize(fileDescriptor)

        guard size >= 0, size <= outputPolicy.limitPerStream else {
            throw ProcessExecutionError.outputLimitExceeded(
                stream,
                outputPolicy.limitPerStream
            )
        }
    }
}

private actor FileDescriptorDrain {

    // MARK: - Private Properties

    private let fileDescriptor: Int32
    private let operations: any CleanupProcessPOSIXOperations
    private let stream: ProcessOutputStream
    private var task: Task<Data, any Error>?

    // MARK: - Initializer

    init(
        _ fileDescriptor: Int32,
        operations: any CleanupProcessPOSIXOperations,
        stream: ProcessOutputStream
    ) {
        self.fileDescriptor = fileDescriptor
        self.operations = operations
        self.stream = stream
    }

    // MARK: - Public Methods

    func data(limit: Int64) async throws -> Data {
        if let task {
            return try await task.value
        }

        let task = Task { [fileDescriptor, operations, stream] in
            try await operations.readToEnd(
                fileDescriptor,
                stream: stream,
                limit: limit
            )
        }
        self.task = task
        return try await task.value
    }

    deinit {
        if task == nil {
            operations.close(fileDescriptor)
        }
    }
}

protocol CStringAllocating {
    func allocate(_ string: String) -> UnsafeMutablePointer<CChar>?
    func release(_ pointer: UnsafeMutablePointer<CChar>)
}

struct SystemCStringAllocator: CStringAllocating {

    // MARK: - Public Methods

    func allocate(_ string: String) -> UnsafeMutablePointer<CChar>? {
        strdup(string)
    }

    func release(_ pointer: UnsafeMutablePointer<CChar>) {
        free(pointer)
    }
}

final class POSIXArgumentVector {

    // MARK: - Private Properties

    private let allocator: any CStringAllocating
    private var pointers: [UnsafeMutablePointer<CChar>]

    // MARK: - Initializer

    init(
        _ strings: [String],
        allocator: any CStringAllocating = SystemCStringAllocator()
    ) throws {
        self.allocator = allocator
        pointers = []

        for string in strings {
            guard let pointer = allocator.allocate(string) else {
                pointers.forEach(allocator.release)
                pointers.removeAll()
                throw POSIXError(.ENOMEM)
            }

            pointers.append(pointer)
        }
    }

    deinit {
        pointers.forEach(allocator.release)
    }

    // MARK: - Public Methods

    func withMutablePointers<Result>(
        _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) throws -> Result
    ) rethrows -> Result {
        var nullablePointers = pointers.map(Optional.some) + [nil]
        return try nullablePointers.withUnsafeMutableBufferPointer {
            try body($0.baseAddress)
        }
    }
}

struct POSIXDescriptorDuplication: Equatable, Sendable {

    // MARK: - Public Properties

    let source: Int32
    let target: Int32
}

struct POSIXKernelSpawnRequest: Equatable, Sendable {

    // MARK: - Public Properties

    let arguments: [String]
    let attributeFlags: Int16
    let duplications: [POSIXDescriptorDuplication]
    let environment: [String]
    let executablePath: String
}

enum POSIXReadResult: Equatable, Sendable {
    case data(Data)
    case endOfFile
    case failure(Int32)
    case interrupted
}

protocol CleanupProcessSpawnSystemCalls: Sendable {
    func advanceReadOffset(_ offset: Int64, count: Int) throws -> Int64
    func close(_ fileDescriptor: Int32)
    func duplicateCloseOnExec(_ fileDescriptor: Int32, minimum: Int32) throws -> Int32
    func fileSize(_ fileDescriptor: Int32) throws -> Int64
    func isRegularFile(_ fileDescriptor: Int32) throws -> Bool
    func openCapture(_ path: String, flags: Int32, mode: mode_t) throws -> Int32
    func read(_ fileDescriptor: Int32, offset: Int64, maximumLength: Int) -> POSIXReadResult
    func spawn(_ request: POSIXKernelSpawnRequest) throws -> pid_t
    func unlink(_ path: String) throws
}

final class SystemCleanupProcessPOSIXOperations: CleanupProcessPOSIXOperations, @unchecked Sendable {

    // MARK: - Private Properties

    private static let outputQueue = DispatchQueue(
        label: "com.cleanerxcode.process-output",
        qos: .utility,
        attributes: .concurrent
    )
    private static let spawnLock = NSLock()
    private let spawnSystemCalls: any CleanupProcessSpawnSystemCalls

    // MARK: - Initializer

    init(_ spawnSystemCalls: any CleanupProcessSpawnSystemCalls = SystemCleanupProcessSpawnSystemCalls()) {
        self.spawnSystemCalls = spawnSystemCalls
    }

    // MARK: - Public Methods

    func close(_ fileDescriptor: Int32) {
        Darwin.close(fileDescriptor)
    }

    func fileSize(_ fileDescriptor: Int32) throws -> Int64 {
        try spawnSystemCalls.fileSize(fileDescriptor)
    }

    func readToEnd(
        _ fileDescriptor: Int32,
        stream: ProcessOutputStream,
        limit: Int64
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            Self.outputQueue.async { [self] in
                continuation.resume(with: Result {
                    try readToEndSynchronously(
                        fileDescriptor,
                        stream: stream,
                        limit: limit
                    )
                })
            }
        }
    }

    func send(_ signal: ChildProcessSignal, to processIdentifier: pid_t) throws {
        let rawSignal = signal == .termination ? SIGTERM : SIGKILL

        guard Darwin.kill(processIdentifier, rawSignal) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }

    func spawn(_ request: CleanupProcessSpawnRequest) throws -> SpawnedCleanupProcess {
        try Self.spawnLock.withLock {
            try spawnIsolated(request)
        }
    }

    func wait(_ processIdentifier: pid_t, noHang: Bool) -> POSIXWaitResult {
        var rawStatus = Int32()
        let waitResult = waitpid(processIdentifier, &rawStatus, noHang ? WNOHANG : 0)

        if waitResult == 0 {
            return .stillRunning
        }

        if waitResult == -1 {
            switch errno {
            case EINTR:
                return .interrupted
            case ECHILD:
                return .noChild
            default:
                return .failure(errno)
            }
        }

        let terminationSignal = rawStatus & 0x7f

        if terminationSignal != 0 {
            return .signaled(terminationSignal)
        }

        return .exited((rawStatus >> 8) & 0xff)
    }

    // MARK: - Private Methods

    private func readToEndSynchronously(
        _ fileDescriptor: Int32,
        stream: ProcessOutputStream,
        limit: Int64
    ) throws -> Data {
        defer {
            spawnSystemCalls.close(fileDescriptor)
        }

        let expectedSize = try spawnSystemCalls.fileSize(fileDescriptor)

        guard expectedSize >= 0, expectedSize <= limit else {
            throw ProcessExecutionError.outputLimitExceeded(stream, limit)
        }

        var data = Data()
        var offset = Int64()

        while offset < expectedSize {
            let remaining = expectedSize - offset
            let maximumLength = Int(min(remaining, Int64(64 * 1_024)))

            switch spawnSystemCalls.read(
                fileDescriptor,
                offset: offset,
                maximumLength: maximumLength
            ) {
            case .data(let chunk):
                guard !chunk.isEmpty, chunk.count <= maximumLength else {
                    throw POSIXError(.EIO)
                }

                data.append(chunk)
                offset = try spawnSystemCalls.advanceReadOffset(
                    offset,
                    count: chunk.count
                )
            case .endOfFile:
                throw POSIXError(.EIO)
            case .interrupted:
                continue
            case .failure(let errorCode):
                throw POSIXError(.init(rawValue: errorCode) ?? .EIO)
            }
        }

        let finalSize = try spawnSystemCalls.fileSize(fileDescriptor)

        guard finalSize >= 0, finalSize <= limit else {
            throw ProcessExecutionError.outputLimitExceeded(stream, limit)
        }

        guard finalSize == expectedSize else {
            throw POSIXError(.EIO)
        }

        return data
    }

    private func makeIsolatedCapture() throws -> Int32 {
        let captureURL = FileManager.default.temporaryDirectory
            .appending(path: "CleanerXcode-\(UUID().uuidString).capture")
        let capturePath = captureURL.path
        let flags = O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC | O_NOFOLLOW
        let rawDescriptor = try spawnSystemCalls.openCapture(
            capturePath,
            flags: flags,
            mode: S_IRUSR | S_IWUSR
        )

        do {
            try spawnSystemCalls.unlink(capturePath)

            guard try spawnSystemCalls.isRegularFile(rawDescriptor) else {
                throw POSIXError(.EINVAL)
            }

            let elevatedDescriptor = try spawnSystemCalls.duplicateCloseOnExec(
                rawDescriptor,
                minimum: STDERR_FILENO + 1
            )
            spawnSystemCalls.close(rawDescriptor)
            return elevatedDescriptor
        } catch {
            spawnSystemCalls.close(rawDescriptor)
            throw error
        }
    }

    private func spawnIsolated(_ request: CleanupProcessSpawnRequest) throws -> SpawnedCleanupProcess {
        let standardOutput = try makeIsolatedCapture()

        do {
            let standardError = try makeIsolatedCapture()

            do {
                return try spawnIsolated(
                    request,
                    standardOutput: standardOutput,
                    standardError: standardError
                )
            } catch {
                spawnSystemCalls.close(standardError)
                throw error
            }
        } catch {
            spawnSystemCalls.close(standardOutput)
            throw error
        }
    }

    private func spawnIsolated(
        _ request: CleanupProcessSpawnRequest,
        standardOutput: Int32,
        standardError: Int32
    ) throws -> SpawnedCleanupProcess {
        let kernelRequest = POSIXKernelSpawnRequest(
            arguments: request.arguments,
            attributeFlags: request.attributeFlags,
            duplications: [
                .init(source: standardOutput, target: request.standardOutputTarget),
                .init(source: standardError, target: request.standardErrorTarget)
            ],
            environment: request.environment,
            executablePath: request.executablePath
        )
        let processIdentifier = try spawnSystemCalls.spawn(kernelRequest)
        return SpawnedCleanupProcess(
            processIdentifier: processIdentifier,
            standardErrorDescriptor: standardError,
            standardOutputDescriptor: standardOutput
        )
    }
}

final class SystemCleanupProcessSpawnSystemCalls: CleanupProcessSpawnSystemCalls, @unchecked Sendable {

    // MARK: - Public Methods

    func advanceReadOffset(_ offset: Int64, count: Int) throws -> Int64 {
        try checkedReadOffset(offset, count: count)
    }

    func close(_ fileDescriptor: Int32) {
        Darwin.close(fileDescriptor)
    }

    func duplicateCloseOnExec(_ fileDescriptor: Int32, minimum: Int32) throws -> Int32 {
        let duplicatedDescriptor = fcntl(fileDescriptor, F_DUPFD_CLOEXEC, minimum)

        guard duplicatedDescriptor >= minimum else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        return duplicatedDescriptor
    }

    func fileSize(_ fileDescriptor: Int32) throws -> Int64 {
        var information = stat()

        guard fstat(fileDescriptor, &information) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        return information.st_size
    }

    func isRegularFile(_ fileDescriptor: Int32) throws -> Bool {
        var information = stat()

        guard fstat(fileDescriptor, &information) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        return information.st_mode & S_IFMT == S_IFREG
    }

    func openCapture(_ path: String, flags: Int32, mode: mode_t) throws -> Int32 {
        let fileDescriptor = Darwin.open(path, flags, mode)

        guard fileDescriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        return fileDescriptor
    }

    func read(_ fileDescriptor: Int32, offset: Int64, maximumLength: Int) -> POSIXReadResult {
        var buffer = [UInt8](repeating: 0, count: maximumLength)
        let count = buffer.withUnsafeMutableBytes {
            pread(fileDescriptor, $0.baseAddress, maximumLength, offset)
        }

        if count > 0 {
            return .data(Data(buffer.prefix(count)))
        }

        if count == 0 {
            return .endOfFile
        }

        return errno == EINTR ? .interrupted : .failure(errno)
    }

    func spawn(_ request: POSIXKernelSpawnRequest) throws -> pid_t {
        var fileActions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        let actionsInitialization = posix_spawn_file_actions_init(&fileActions)

        guard actionsInitialization == 0 else {
            throw POSIXError(.init(rawValue: actionsInitialization) ?? .EIO)
        }

        defer {
            posix_spawn_file_actions_destroy(&fileActions)
        }

        let attributesInitialization = posix_spawnattr_init(&attributes)

        guard attributesInitialization == 0 else {
            throw POSIXError(.init(rawValue: attributesInitialization) ?? .EIO)
        }

        defer {
            posix_spawnattr_destroy(&attributes)
        }

        let attributeResult = posix_spawnattr_setflags(
            &attributes,
            request.attributeFlags
        )

        if attributeResult != 0 {
            throw POSIXError(.init(rawValue: attributeResult) ?? .EIO)
        }

        for duplication in request.duplications {
            let result = posix_spawn_file_actions_adddup2(
                &fileActions,
                duplication.source,
                duplication.target
            )

            if result != 0 {
                throw POSIXError(.init(rawValue: result) ?? .EIO)
            }
        }

        let arguments = try POSIXArgumentVector(request.arguments)
        let environment = try POSIXArgumentVector(request.environment)
        var processIdentifier = pid_t()
        let spawnResult = arguments.withMutablePointers { argumentPointers in
            environment.withMutablePointers { environmentPointers in
                posix_spawn(
                    &processIdentifier,
                    request.executablePath,
                    &fileActions,
                    &attributes,
                    argumentPointers,
                    environmentPointers
                )
            }
        }

        guard spawnResult == 0 else {
            throw POSIXError(.init(rawValue: spawnResult) ?? .EIO)
        }

        return processIdentifier
    }

    func unlink(_ path: String) throws {
        while Darwin.unlink(path) != 0 {
            guard errno == EINTR else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
        }
    }

    // MARK: - Private Methods

    private func checkedReadOffset(_ offset: Int64, count: Int) throws -> Int64 {
        let (newOffset, overflow) = offset.addingReportingOverflow(Int64(count))

        guard !overflow, newOffset >= offset else {
            throw POSIXError(.EOVERFLOW)
        }

        return newOffset
    }
}

struct SimulatorControlService: Sendable {

    // MARK: - Private Properties

    private let executor: any XcrunExecuting
    private let timeout: Duration

    // MARK: - Initializer

    init(
        _ executor: any XcrunExecuting = XcrunProcessExecutor(),
        timeout: Duration = .seconds(60)
    ) {
        self.executor = executor
        self.timeout = timeout
    }

    // MARK: - Public Methods

    func deleteUnavailable() async throws -> ProcessExecutionResult {
        try await executor.execute(.deleteUnavailableSimulators, timeout: timeout)
    }

    func shutdownAll() async throws -> ProcessExecutionResult {
        try await executor.execute(.shutdownAllSimulators, timeout: timeout)
    }
}
