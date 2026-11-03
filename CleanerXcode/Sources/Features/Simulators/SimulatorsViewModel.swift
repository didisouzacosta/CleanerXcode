//
//  SimulatorsViewModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Observation

/// The simulators of the default set and the installed runtimes (R8, R9). "Remover duplicados"
/// only pre-selects; every deletion waits for a confirmation, sends the exact UDIDs or runtime
/// identifier to `simctl`, and reloads the lists to show the result. It also downloads runtimes
/// (C30), one platform at a time, never together with a runtime deletion.
@Observable
final class SimulatorsViewModel {

    // MARK: - Public Properties

    /// Read by the composition tests.
    let simulators: any SimulatorManaging
    let downloader: any RuntimeDownloading

    private(set) var phase: SimulatorsPhase = .idle
    private(set) var devices: [SimulatorDevice] = []
    private(set) var runtimes: [SimulatorRuntime] = []
    private(set) var selectedUDIDs: Set<String> = []
    private(set) var confirmation: Confirmation?
    /// The last deletion that failed; cleared by the next one.
    private(set) var lastFailure: CleanupError?
    private(set) var runtimeDownload: RuntimeDownloadState = .idle
    /// The open "Download runtimes" sheet.
    private(set) var downloadChoice: RuntimeDownloadChoice?

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
    @ObservationIgnored private var downloadTask: Task<Bool, Never>?

    // MARK: - Initializers

    /// `onDeleted` lets the window measure again after something was deleted.
    init(
        simulators: any SimulatorManaging,
        downloader: any RuntimeDownloading,
        analytics: any Analytics,
        onDeleted: @escaping () async -> Void = {}
    ) {
        self.simulators = simulators
        self.downloader = downloader
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

        guard !phase.isDeleting, downloadChoice == nil, !selected.isEmpty else { return }

        confirmation = .devices(selected)
    }

    /// Runtimes bundled with Xcode cannot be deleted, nor any runtime while one is downloaded.
    func requestDeleteRuntime(_ runtime: SimulatorRuntime) {
        guard !phase.isDeleting, !runtimeDownload.isDownloading, downloadChoice == nil, runtime.isDeletable else {
            return
        }

        confirmation = .runtime(runtime, dependentCount: dependents(removedWith: runtime, in: devices).count)
    }

    func cancelConfirmation() {
        confirmation = nil
    }

    func confirm() async {
        guard let confirmation else { return }

        self.confirmation = nil

        // A download started while the runtime confirmation was open: the list is about to change.
        if case .runtime = confirmation, runtimeDownload.isDownloading {
            return
        }

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

extension SimulatorsViewModel {

    // MARK: - Runtime Download

    /// With the lists and on the empty state; otherwise only for a download in progress or
    /// finished, so it can still be cancelled or read.
    var showsRuntimeDownload: Bool {
        phase.showsLists || phase == .empty || runtimeDownload != .idle
    }

    /// Opens the "Download runtimes" sheet with nothing selected (Q9). Never during a download, a
    /// deletion or with a deletion confirmation open. A finished result stays until the next queue.
    func requestRuntimeDownload() {
        guard !runtimeDownload.isDownloading, !phase.isDeleting, confirmation == nil else { return }

        downloadChoice = RuntimeDownloadChoice()
    }

    func toggleRuntimePlatform(_ platform: RuntimePlatform) {
        downloadChoice?.toggle(platform)
    }

    func cancelRuntimeDownloadChoice() {
        downloadChoice = nil
    }

    /// Closes the sheet and downloads the selected platforms. With nothing selected, or during a
    /// download or a deletion, it does nothing and the sheet stays.
    func confirmRuntimeDownload() async {
        guard
            let choice = downloadChoice,
            !choice.selected.isEmpty,
            !runtimeDownload.isDownloading,
            !phase.isDeleting
        else { return }

        downloadChoice = nil
        await runDownloads(choice.orderedSelection)
    }

    /// "Try again": downloads only the platforms that failed, without the sheet. Never with the
    /// sheet open, as no deletion is asked then either. A deletion confirmation still open is left
    /// to `confirm()`, which drops a runtime removal while a download runs and lets simulators go.
    func retryFailedRuntimeDownloads() async {
        guard case let .finished(run) = runtimeDownload, !run.failed.isEmpty, downloadChoice == nil else { return }

        await runDownloads(run.failed.map(\.platform))
    }

    /// Terminates the current download and empties the queue; the state changes when it has ended.
    func cancelRuntimeDownload() {
        downloadTask?.cancel()
    }

    /// Leaving the page clears a finished result; a download in progress goes on.
    func dismissRuntimeDownloadResult() {
        guard runtimeDownload.isFinished else { return }

        runtimeDownload = .idle
    }

    /// One task for the whole queue. It inherits the main actor, because it records the state
    /// between downloads; the process runs off it in `ProcessRunner`. A failure does not stop the
    /// queue, except missing tools, which every platform would hit (Q8). Each installed runtime is
    /// listed at once (`listShieldedFromCancel`), before the next download starts, so listings never
    /// overlap. After the task, the lists reload only if they may be stale. Never during a deletion,
    /// which lists at its end (B6).
    private func runDownloads(_ platforms: [RuntimePlatform]) async {
        guard !platforms.isEmpty, !runtimeDownload.isDownloading, !phase.isDeleting else { return }

        // Set before the first suspension, so a second call returns at the guard.
        runtimeDownload = .downloading(RuntimeDownloadRun(platforms))

        let downloader = downloader
        let task = Task {
            var run = RuntimeDownloadRun(platforms)

            var isListCurrent = false

            for platform in run.platforms {
                guard !Task.isCancelled else { break }

                do {
                    try await downloader.download(platform, buildVersion: nil)
                    run.record(.installed, for: platform)
                    self.runtimeDownload = .downloading(run)
                    isListCurrent = await self.listShieldedFromCancel()
                } catch {
                    let failure = CleanupError(error)

                    // A download stopped or failed midway may still have changed the runtimes.
                    isListCurrent = false

                    guard failure != .cancelled else { break }

                    run.record(.failed(failure), for: platform)

                    if failure == .toolUnavailable {
                        run.recordRemaining(.failed(.toolUnavailable))
                        break
                    }
                }

                self.runtimeDownload = .downloading(run)
            }

            run.recordRemaining(.notDownloaded)
            self.runtimeDownload = .finished(run)

            return isListCurrent
        }

        downloadTask = task

        let isListCurrent = await task.value

        if downloadTask == task {
            downloadTask = nil
        }

        if !isListCurrent, !phase.isDeleting {
            await reload()
        }
    }

    /// Lists in a task of its own, which a cancelled queue does not cancel: a cancelled listing
    /// would end as `.failed(.cancelled)` (A1 §5). `false` when skipped during a deletion.
    private func listShieldedFromCancel() async -> Bool {
        guard !phase.isDeleting else { return false }

        await Task { await self.reload() }.value

        return true
    }

}
