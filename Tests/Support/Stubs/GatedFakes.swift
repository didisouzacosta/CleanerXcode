//
//  GatedFakes.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Holds every scan of one root until `release()`, and signals each time a scan arrives, so a
/// test can act while a measurement is in the middle without sleeping.
nonisolated final class GatedScannerStub: DiskUsageScanning, Sendable {

    // MARK: - Public Properties

    let arrivals = AsyncStream.makeStream(of: Void.self)

    // MARK: - Private Properties

    private let gatedRoot: URL
    private let size: Int64
    private let state = Mutex<(isOpen: Bool, waiters: [CheckedContinuation<Void, Never>])>((false, []))

    // MARK: - Initializers

    init(gatedRoot: URL, size: Int64) {
        self.gatedRoot = gatedRoot
        self.size = size
    }

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupTarget) async throws -> Int64 {
        guard target.root == gatedRoot else { return 0 }

        arrivals.continuation.yield()

        await withCheckedContinuation { continuation in
            let isOpen = state.withLock { state in
                if !state.isOpen {
                    state.waiters.append(continuation)
                }

                return state.isOpen
            }

            if isOpen {
                continuation.resume()
            }
        }

        return size
    }

    /// Holds the next scans again.
    func close() {
        state.withLock { $0.isOpen = false }
    }

    func release() {
        let waiters = state.withLock { state in
            state.isOpen = true

            defer { state.waiters = [] }
            return state.waiters
        }

        waiters.forEach { $0.resume() }
    }

}

/// The first listing of the default set waits until its task is cancelled; later listings answer
/// at once. It signals when that first listing starts.
nonisolated final class GatedSimulatorManager: SimulatorManaging, Sendable {

    // MARK: - Public Properties

    let arrivals = AsyncStream.makeStream(of: Void.self)

    // MARK: - Private Properties

    private let calls = Mutex(0)

    // MARK: - Public Methods

    func listDevices(in set: DeviceSet) async throws -> [SimulatorDevice] {
        let call = calls.withLock { count in
            count += 1
            return count
        }

        if call == 1 {
            arrivals.continuation.yield()
            try? await Task.sleep(for: .seconds(60))
        }

        return []
    }

    func listRuntimes() throws -> [SimulatorRuntime] {
        []
    }

    func shutdownAll(in set: DeviceSet) throws {}

    func delete(_ devices: [SimulatorDevice], in set: DeviceSet) throws {}

    func deleteUnavailable() throws {}

    func eraseAll() throws {}

    func deleteAllDevices(in set: DeviceSet) throws {}

    func deleteRuntime(identifier: String) throws {}

    func restartService() throws {}

}

/// Every command waits until its task is cancelled, signalling when it arrives, so a test can
/// cancel a long command such as a runtime download without sleeping.
nonisolated final class GatedProcessRunner: ProcessRunning, Sendable {

    // MARK: - Public Properties

    let arrivals = AsyncStream.makeStream(of: Void.self)

    var wasCancelled: Bool {
        cancelled.withLock { $0 }
    }

    // MARK: - Private Properties

    private let cancelled = Mutex(false)

    // MARK: - Public Methods

    func run(_ request: ProcessRequest) async throws -> ProcessOutput {
        arrivals.continuation.yield()

        do {
            try await Task.sleep(for: .seconds(3_600))
        } catch {
            cancelled.withLock { $0 = true }
            throw error
        }

        return ProcessOutput(standardOutput: Data(), standardError: Data())
    }

}
