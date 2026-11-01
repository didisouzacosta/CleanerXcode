//
//  SimulatorsViewModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Observation

/// The simulators of the default set and the installed runtimes (R8, R9). "Remover duplicados"
/// only pre-selects; every deletion waits for a confirmation, sends the exact UDIDs or runtime
/// identifier to `simctl`, and reloads the lists to show the result.
@Observable
final class SimulatorsViewModel {

    // MARK: - Public Properties

    /// Read by the composition tests.
    let simulators: any SimulatorManaging

    private(set) var phase: SimulatorsPhase = .idle
    private(set) var devices: [SimulatorDevice] = []
    private(set) var runtimes: [SimulatorRuntime] = []
    private(set) var selectedUDIDs: Set<String> = []
    private(set) var confirmation: Confirmation?
    /// The last deletion that failed; cleared by the next one.
    private(set) var lastFailure: CleanupError?

    /// The ones suggested for removal: the most recent of each group stays.
    var duplicateUDIDs: Set<String> {
        Set(DuplicateSimulatorDetector.suggestedForRemoval(in: devices).map(\.udid))
    }

    var selectedBytes: Int64 {
        devices.filter { selectedUDIDs.contains($0.udid) }.reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Private Properties

    private let analytics: any Analytics
    private let onDeleted: () async -> Void

    /// Each listing takes one; a deletion or a newer listing makes the older ones stale.
    @ObservationIgnored private var reloadGeneration = 0

    // MARK: - Initializers

    /// `onDeleted` lets the window measure again after something was deleted.
    init(simulators: any SimulatorManaging, analytics: any Analytics, onDeleted: @escaping () async -> Void = {}) {
        self.simulators = simulators
        self.analytics = analytics
        self.onDeleted = onDeleted
    }

    // MARK: - Public Methods

    func load() async {
        guard !phase.isDeleting else { return }

        phase = .loading
        await reload()
    }

    /// The window's activation lists only the first time, from `idle`, so the overview card and
    /// the sidebar badge have the lists (D9). With no simulators, without the tools or after a
    /// failure, activating the window again never runs `simctl` again; the page and Refresh do.
    func loadOnActivation() async {
        guard phase == .idle else { return }

        await load()
    }

    /// Opening the "Simulators and runtimes" page: lists unless the lists are shown, being listed
    /// or being changed, so an empty list, a failure or missing tools are tried again.
    func loadIfNeeded() async {
        switch phase {
        case .loaded, .loading, .deleting:
            return

        case .idle, .empty, .toolsUnavailable, .failed:
            await load()
        }
    }

    /// The toolbar's Refresh: lists again only lists that were already loaded once.
    func reloadIfOpened() async {
        switch phase {
        case .idle, .loading, .deleting:
            return

        default:
            await reload()
        }
    }

    func dependentCount(of runtime: SimulatorRuntime) -> Int {
        devices.count { $0.runtimeIdentifier == runtime.runtimeIdentifier }
    }

    func toggle(_ udid: String) {
        guard !phase.isDeleting else { return }

        if selectedUDIDs.contains(udid) {
            selectedUDIDs.remove(udid)
        } else {
            selectedUDIDs.insert(udid)
        }
    }

    /// Pre-selects the duplicates; it never deletes on its own (R8).
    func selectDuplicates() {
        guard !phase.isDeleting else { return }

        selectedUDIDs.formUnion(duplicateUDIDs)
    }

    func requestDeleteSelected() {
        let selected = devices.filter { selectedUDIDs.contains($0.udid) }

        guard !phase.isDeleting, !selected.isEmpty else { return }

        confirmation = .devices(selected)
    }

    /// Runtimes bundled with Xcode cannot be deleted.
    func requestDeleteRuntime(_ runtime: SimulatorRuntime) {
        guard !phase.isDeleting, runtime.isDeletable else { return }

        confirmation = .runtime(runtime, dependentCount: dependents(removedWith: runtime, in: devices).count)
    }

    func cancelConfirmation() {
        confirmation = nil
    }

    func confirm() async {
        guard let confirmation else { return }

        self.confirmation = nil
        lastFailure = nil

        switch confirmation {
        case let .devices(devices):
            await delete(devices)

        case let .runtime(runtime, _):
            await delete(runtime)
        }

        await reload()
        await onDeleted()
    }

    // MARK: - Private Methods

    /// Lists again first, so a simulator booted since the list loaded is still shut down before
    /// it is deleted; the ones that no longer exist are left out.
    private func delete(_ devices: [SimulatorDevice]) async {
        let udids = Set(devices.map(\.udid))
        let reason: AnalyticsEvent.SimulatorDeletionReason = udids.isSubset(of: duplicateUDIDs) ? .duplicate : .manual

        phase = .deleting(udids)
        reloadGeneration += 1

        do {
            let current = try await simulators.listDevices(in: .default).filter { udids.contains($0.udid) }

            guard !current.isEmpty else { return }

            try await simulators.delete(current, in: .default)
            analytics.log(.simulatorDeleted(count: current.count, reason: reason))
        } catch {
            lastFailure = CleanupError(error)
        }
    }

    /// `simctl runtime delete` is not known to delete the simulators that use the runtime, so they
    /// are deleted first, by exact UDID; when that fails, the runtime is kept (R9).
    private func delete(_ runtime: SimulatorRuntime) async {
        phase = .deleting([runtime.identifier])
        reloadGeneration += 1

        do {
            let current = try await simulators.listDevices(in: .default)
            let dependents = dependents(removedWith: runtime, in: current)

            if !dependents.isEmpty {
                try await simulators.delete(dependents, in: .default)
            }

            try await simulators.deleteRuntime(identifier: runtime.identifier)
            analytics.log(.runtimeDeleted(count: 1))
        } catch {
            lastFailure = CleanupError(error)
        }
    }

    /// The simulators that lose their runtime: none while another image serves the same runtime.
    private func dependents(removedWith runtime: SimulatorRuntime, in devices: [SimulatorDevice]) -> [SimulatorDevice] {
        let isServedElsewhere = runtimes.contains {
            $0.identifier != runtime.identifier && $0.runtimeIdentifier == runtime.runtimeIdentifier
        }

        guard !isServedElsewhere else { return [] }

        return devices.filter { $0.runtimeIdentifier == runtime.runtimeIdentifier }
    }

    /// Lists both again; the selection keeps only the devices that still exist. A listing that
    /// became stale (a deletion or a newer listing started meanwhile) is discarded.
    private func reload() async {
        reloadGeneration += 1

        let generation = reloadGeneration

        do {
            async let listedDevices = simulators.listDevices(in: .default)
            async let listedRuntimes = simulators.listRuntimes()

            let (newDevices, newRuntimes) = try await (listedDevices, listedRuntimes)

            guard generation == reloadGeneration else { return }

            devices = newDevices
            runtimes = newRuntimes
            selectedUDIDs.formIntersection(devices.map(\.udid))
            phase = devices.isEmpty && runtimes.isEmpty ? .empty : .loaded
        } catch {
            guard generation == reloadGeneration else { return }

            let failure = CleanupError(error)

            phase = failure == .toolUnavailable ? .toolsUnavailable : .failed(failure)
        }
    }

    // MARK: - Nested Types

    enum Confirmation: Equatable, Identifiable {

        // MARK: - Cases

        case devices([SimulatorDevice])
        case runtime(SimulatorRuntime, dependentCount: Int)

        // MARK: - Public Properties

        var id: String {
            switch self {
            case let .devices(devices): "devices:" + devices.map(\.udid).joined(separator: ",")
            case let .runtime(runtime, _): "runtime:" + runtime.identifier
            }
        }

    }

}
