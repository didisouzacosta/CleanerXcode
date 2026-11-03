//
//  SimulatorsServiceSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
@testable import CleanerXcode

/// Keeps a default set and a runtime list in memory, applies the deletions it receives and records
/// them in order, so a reload shows the result. It never runs `simctl`. Deleting a runtime only
/// removes the runtime: whether `simctl runtime delete` also removes its simulators is not known,
/// so the view model deletes them itself.
nonisolated final class SimulatorsServiceSpy: SimulatorManaging, Sendable {

    // MARK: - Public Properties

    /// Signals each deletion as it starts; with `holdsDeletions` it waits for `releaseDeletions()`.
    let deletionStarted = AsyncStream<Void>.makeStream()
    /// Signals when a listing is parked by `holdNextListing()`.
    let listingHeld = AsyncStream<Void>.makeStream()

    /// `delete <udids>`, `runtime delete <id>` and `shutdown all`, in order.
    var calls: [String] {
        state.withLock { $0.calls }
    }

    /// The devices passed to each `delete`, with the state they had when passed.
    var deletedDevices: [[SimulatorDevice]] {
        state.withLock { $0.deletedDevices }
    }

    var deletedRuntimes: [String] {
        state.withLock { $0.deletedRuntimes }
    }

    /// How many device listings ran.
    var listingCount: Int {
        state.withLock { $0.listingCount }
    }

    // MARK: - Private Properties

    private let state: Mutex<State>

    // MARK: - Initializers

    init(
        devices: [SimulatorDevice] = [],
        runtimes: [SimulatorRuntime] = [],
        listFailure: CleanupError? = nil,
        deleteFailure: CleanupError? = nil,
        runtimeDeleteFailure: CleanupError? = nil,
        holdsDeletions: Bool = false
    ) {
        state = Mutex(State(
            devices: devices,
            runtimes: runtimes,
            listFailure: listFailure,
            deleteFailure: deleteFailure,
            runtimeDeleteFailure: runtimeDeleteFailure,
            holdsDeletions: holdsDeletions
        ))
    }

    // MARK: - Public Methods

    func setListFailure(_ failure: CleanupError?) {
        state.withLock { $0.listFailure = failure }
    }

    /// Changes a device behind the view model's back, as a boot from Xcode would.
    func boot(_ udid: String) {
        state.withLock { state in
            state.devices = state.devices.map { device in
                guard device.udid == udid else { return device }

                return SimulatorDevice(
                    udid: device.udid,
                    name: device.name,
                    deviceTypeIdentifier: device.deviceTypeIdentifier,
                    runtimeIdentifier: device.runtimeIdentifier,
                    state: .booted,
                    isAvailable: device.isAvailable,
                    lastUsedAt: device.lastUsedAt,
                    sizeBytes: device.sizeBytes
                )
            }
        }
    }

    /// Adds a runtime behind the view model's back, as a finished download would.
    func install(_ runtime: SimulatorRuntime) {
        state.withLock { $0.runtimes.append(runtime) }
    }

    /// The next device listing waits for `releaseListing()`.
    func holdNextListing() {
        state.withLock { $0.holdsNextListing = true }
    }

    func releaseListing() {
        let waiter = state.withLock { state in
            defer { state.listingWaiter = nil }
            return state.listingWaiter
        }

        waiter?.resume()
    }

    func releaseDeletions() {
        let waiters = state.withLock { state in
            state.holdsDeletions = false

            defer { state.waiters = [] }
            return state.waiters
        }

        waiters.forEach { $0.resume() }
    }

    func listDevices(in set: DeviceSet) async throws -> [SimulatorDevice] {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumeNow = state.withLock { state in
                guard state.holdsNextListing else { return true }

                state.holdsNextListing = false
                state.listingWaiter = continuation
                return false
            }

            if resumeNow {
                continuation.resume()
            } else {
                listingHeld.continuation.yield()
            }
        }

        return try state.withLock { state in
            state.listingCount += 1

            if let failure = state.listFailure {
                throw failure
            }

            return set == .default ? state.devices : []
        }
    }

    func listRuntimes() throws -> [SimulatorRuntime] {
        try state.withLock { state in
            if let failure = state.listFailure {
                throw failure
            }

            return state.runtimes
        }
    }

    func delete(_ devices: [SimulatorDevice], in set: DeviceSet) async throws {
        await waitIfHeld()

        try state.withLock { state in
            let udids = devices.map(\.udid)

            state.calls.append("delete \(udids.joined(separator: " "))")

            if let failure = state.deleteFailure {
                throw failure
            }

            state.deletedDevices.append(devices)
            state.devices.removeAll { udids.contains($0.udid) }
        }
    }

    func deleteRuntime(identifier: String) async throws {
        await waitIfHeld()

        try state.withLock { state in
            state.calls.append("runtime delete \(identifier)")

            if let failure = state.runtimeDeleteFailure {
                throw failure
            }

            state.deletedRuntimes.append(identifier)
            state.runtimes.removeAll { $0.identifier == identifier }
        }
    }

    func shutdownAll(in set: DeviceSet) throws {
        state.withLock { $0.calls.append("shutdown all") }
    }

    func deleteUnavailable() throws {}

    func eraseAll() throws {}

    func deleteAllDevices(in set: DeviceSet) throws {}

    func restartService() throws {}

    // MARK: - Private Methods

    private func waitIfHeld() async {
        deletionStarted.continuation.yield()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumeNow = state.withLock { state in
                guard state.holdsDeletions else { return true }

                state.waiters.append(continuation)
                return false
            }

            if resumeNow {
                continuation.resume()
            }
        }
    }

    // MARK: - Nested Types

    private struct State {

        // MARK: - Public Properties

        var devices: [SimulatorDevice]
        var runtimes: [SimulatorRuntime]
        var listFailure: CleanupError?
        var deleteFailure: CleanupError?
        var runtimeDeleteFailure: CleanupError?
        var holdsDeletions: Bool
        var holdsNextListing = false
        var listingWaiter: CheckedContinuation<Void, Never>?
        var waiters: [CheckedContinuation<Void, Never>] = []
        var calls: [String] = []
        var deletedDevices: [[SimulatorDevice]] = []
        var deletedRuntimes: [String] = []
        var listingCount = 0

    }

}
