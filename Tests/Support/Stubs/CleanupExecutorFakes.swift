//
//  CleanupExecutorFakes.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// One ordered log shared by every fake, so a test checks the global order of the steps.
nonisolated final class CallLog: Sendable {

    // MARK: - Public Properties

    var calls: [String] {
        state.withLock { $0 }
    }

    // MARK: - Private Properties

    private let state = Mutex<[String]>([])

    // MARK: - Public Methods

    func record(_ call: String) {
        state.withLock { $0.append(call) }
    }

}

/// Answers each target with fixed results and never touches the disk.
nonisolated final class RemoverSpy: FileRemoving, Sendable {

    // MARK: - Public Properties

    var filters: [CleanupCategoryID: @Sendable (URL) -> Bool] {
        state.withLock { $0 }
    }

    /// Full paths of every root it was asked to empty.
    var roots: [String] {
        rootsState.withLock { $0 }
    }

    // MARK: - Private Properties

    private let log: CallLog
    /// Keyed by the last component of the target root.
    private let outcomes: [String: [(bytes: Int64, outcome: CleanupItemResult.Outcome)]]
    private let cancelsAfter: CleanupCategoryID?
    private let state = Mutex<[CleanupCategoryID: @Sendable (URL) -> Bool]>([:])
    private let rootsState = Mutex<[String]>([])

    // MARK: - Initializers

    init(
        log: CallLog,
        outcomes: [String: [(bytes: Int64, outcome: CleanupItemResult.Outcome)]] = [:],
        cancelsAfter: CleanupCategoryID? = nil
    ) {
        self.log = log
        self.outcomes = outcomes
        self.cancelsAfter = cancelsAfter
    }

    // MARK: - Public Methods

    func removeContents(
        of target: CleanupTarget,
        categoryID: CleanupCategoryID,
        mode: RemovalMode,
        filter: @escaping @Sendable (URL) -> Bool,
        onResult: (CleanupItemResult) -> Void
    ) throws {
        let name = target.root.lastPathComponent

        log.record("remove \(categoryID.rawValue) \(name) \(mode)")
        rootsState.withLock { $0.append(target.root.path(percentEncoded: false)) }
        state.withLock { $0[categoryID] = filter }

        for (index, item) in outcomes[name, default: []].enumerated() {
            onResult(CleanupItemResult(
                categoryID: categoryID,
                displayPath: "~/\(name)/item-\(index)",
                bytes: item.bytes,
                outcome: item.outcome
            ))
        }

        if categoryID == cancelsAfter {
            withUnsafeCurrentTask { $0?.cancel() }
        }
    }

}

nonisolated final class SimulatorManagerSpy: SimulatorManaging, Sendable {

    // MARK: - Public Properties

    /// Full paths of every custom set it was given.
    var setPaths: [String] {
        setPathsState.withLock { $0 }
    }

    // MARK: - Private Properties

    private let log: CallLog
    private let failures: [String: CleanupError]
    private let unavailableSizes: [Int64]
    private let setPathsState = Mutex<[String]>([])

    // MARK: - Initializers

    init(log: CallLog, failures: [String: CleanupError] = [:], unavailableSizes: [Int64] = []) {
        self.log = log
        self.failures = failures
        self.unavailableSizes = unavailableSizes
    }

    // MARK: - Public Methods

    func listDevices(in set: DeviceSet) throws -> [SimulatorDevice] {
        try record("list \(name(of: set))")

        return unavailableSizes.enumerated().map { index, size in
            SimulatorDevice(
                udid: "UNAVAILABLE-\(index)",
                name: "Old",
                deviceTypeIdentifier: "type",
                runtimeIdentifier: "runtime",
                state: .shutdown,
                isAvailable: false,
                lastUsedAt: nil,
                sizeBytes: size
            )
        }
    }

    func listRuntimes() throws -> [SimulatorRuntime] {
        []
    }

    func shutdownAll(in set: DeviceSet) throws {
        try record("shutdownAll \(name(of: set))")
    }

    func delete(_ devices: [SimulatorDevice], in set: DeviceSet) throws {
        try record("delete")
    }

    func deleteUnavailable() throws {
        try record("deleteUnavailable")
    }

    func eraseAll() throws {
        try record("eraseAll")
    }

    func deleteAllDevices(in set: DeviceSet) throws {
        try record("deleteAll \(name(of: set))")
    }

    func deleteRuntime(identifier: String) throws {
        try record("deleteRuntime")
    }

    func restartService() throws {
        try record("restartService")
    }

    // MARK: - Private Methods

    private func record(_ call: String) throws {
        log.record(call)

        if let failure = failures[call] {
            throw failure
        }
    }

    private func name(of set: DeviceSet) -> String {
        switch set {
        case .default:
            return "default"

        case let .custom(url):
            setPathsState.withLock { $0.append(url.path(percentEncoded: false)) }
            return url.lastPathComponent
        }
    }

}

@MainActor
final class RunningApplicationsFake: RunningApplicationsProviding {

    // MARK: - Public Properties

    var isXcodeRunning = false
    var isSimulatorRunning = false

    // MARK: - Private Properties

    private let log: CallLog
    private let quits: Bool
    private let cancelsWhileQuitting: Bool

    // MARK: - Initializers

    init(log: CallLog, isXcodeRunning: Bool = false, quits: Bool = true, cancelsWhileQuitting: Bool = false) {
        self.log = log
        self.isXcodeRunning = isXcodeRunning
        self.quits = quits
        self.cancelsWhileQuitting = cancelsWhileQuitting
    }

    // MARK: - Public Methods

    func terminateSimulator() -> Bool {
        log.record("terminateSimulator")

        if cancelsWhileQuitting {
            withUnsafeCurrentTask { $0?.cancel() }
        }

        return quits
    }

}

nonisolated struct PreferencesResetterSpy: XcodePreferencesResetting {

    // MARK: - Public Properties

    let log: CallLog
    let domain: String

    var failure: CleanupError?

    // MARK: - Public Methods

    func reset() throws {
        log.record("reset \(domain)")

        if let failure {
            throw failure
        }
    }

}

/// Returns the next size of each root on every call, so before and after can differ.
nonisolated final class SequencedScannerStub: DiskUsageScanning, Sendable {

    // MARK: - Private Properties

    private let state: Mutex<[String: [Int64]]>
    private let calls = Mutex<[String: Int]>([:])
    /// Cancels the task and throws on the given call number of a root, like a cancelled scan.
    private let cancelsOnCall: [String: Int]

    // MARK: - Initializers

    /// Keyed by the last component of the root; a root without sizes measures 0.
    init(sizes: [String: [Int64]] = [:], cancelsOnCall: [String: Int] = [:]) {
        state = Mutex(sizes)
        self.cancelsOnCall = cancelsOnCall
    }

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupTarget) throws -> Int64 {
        let key = target.root.lastPathComponent
        let call = calls.withLock { counts in
            counts[key, default: 0] += 1
            return counts[key, default: 0]
        }

        if cancelsOnCall[key] == call {
            withUnsafeCurrentTask { $0?.cancel() }
            throw CancellationError()
        }

        return state.withLock { sizes in
            guard var queue = sizes[key], !queue.isEmpty else { return 0 }

            let next = queue.removeFirst()
            sizes[key] = queue
            return next
        }
    }

}
