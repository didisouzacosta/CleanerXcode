//
//  CleanerViewModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Observation

/// The single window's state and intents (plan section 2.4). It measures on demand, for the menu
/// bar icon every half hour (C40) and, when their folders change, only the changed categories
/// (C40 · tempo real), never during a cleanup (R1); it asks before plans with
/// attention or danger, or that would close Xcode-related work or the simulators (R5, F31); it
/// runs plans through the executor and keeps the report on screen until the user dismisses it.
/// Analytics and error reports only go through their protocols, in `CleanupOutcomeReporter`.
@Observable
final class CleanerViewModel {

    // MARK: - Public Properties

    let categories: [CleanupCategory]

    private(set) var phase: CleanerPhase = .measuring(first: true)
    private(set) var rows: [CleanupCategoryID: CategoryRowState]
    private(set) var selectedIDs: Set<CleanupCategoryID>
    private(set) var restrictions = CleanupRestrictions(
        categories: [],
        isXcodeRunning: false,
        areSimulatorsActive: false
    )

    /// From Settings (D7); fixed in each plan when it is requested.
    private(set) var minimumTemporaryAgeInDays: Int

    /// For tests: how many measurements started.
    @ObservationIgnored private(set) var measurementCount = 0

    /// When the last complete measurement ended; it postpones the background one (C40).
    @ObservationIgnored private(set) var lastMeasuredAt: Date?

    /// When the measurement behind each row's current size started, from any origin.
    @ObservationIgnored private(set) var measurementStarts: [CleanupCategoryID: Date] = [:]

    /// The simulators as the last complete measurement saw them; a category measurement reuses it
    /// instead of running `simctl` (C40 · tempo real).
    @ObservationIgnored private(set) var lastSnapshot: SimulatorSnapshot?

    /// Estimated (R2): clones and hard links can make the freed space differ.
    var totalBytes: Int64 {
        plannedCategories.reduce(0) { total, category in
            guard case let .measured(bytes) = rows[category.id] else { return total }

            return total + bytes
        }
    }

    /// Plans with attention or danger, or with a warning for open apps, ask first (R5, F31).
    var cleanNeedsConfirmation: Bool {
        plannedCategories.contains { $0.risk != .safe || restrictions.warnings[$0.id] != nil }
    }

    /// The risks of what would be cleaned now, for the panel's note.
    var plannedRisks: [RiskLevel] {
        plannedCategories.map(\.risk)
    }

    var canClean: Bool {
        phase == .ready
    }

    /// The selected categories that go to the Trash, for the fixed notice and the confirmation.
    var trashBoundCategoryIDs: Set<CleanupCategoryID> {
        Set(plannedCategories.filter { $0.operation == .removeContents(.trash) }.map(\.id))
    }

    // MARK: - Private Properties

    private var plannedCategories: [CleanupCategory] {
        categories.filter { selectedIDs.contains($0.id) && !isUnavailable($0.id) }
    }

    private var shouldMeasureOnActivation: Bool {
        guard !isMeasuringAll, phase.allowsMeasurement else { return false }

        guard let lastMeasuredAt else { return true }

        return now().timeIntervalSince(lastMeasuredAt) >= measurementCacheDuration
    }

    private let catalog: CleanupCatalog
    private let measurer: CategorySizeMeasurer
    private let snapshotReader: SimulatorSnapshotReader
    private let simulators: any SimulatorManaging
    private let executor: any CleanupExecuting
    private let preferences: any PreferencesStoring
    private let runningApplications: any RunningApplicationsProviding
    private let reporter: CleanupOutcomeReporter

    private var temporaryPolicy: TemporaryItemsPolicy

    private let appBundleIdentifier: String

    private let now: () -> Date
    private let activationDebounce: Duration
    private let measurementCacheDuration: TimeInterval

    @ObservationIgnored private var measurementTask: Task<Void, Never>?
    @ObservationIgnored private var activationTask: Task<Void, Never>?
    @ObservationIgnored private var cleanupTask: Task<CleanupReport, Never>?
    @ObservationIgnored private var measurementGeneration = 0
    @ObservationIgnored private var hasBootedSimulators = false
    /// For tests: a measurement is running or about to start.
    @ObservationIgnored private(set) var isMeasuring = false
    @ObservationIgnored private var isMeasuringAll = false

    // MARK: - Initializers

    init(
        catalog: CleanupCatalog,
        measurer: CategorySizeMeasurer,
        simulators: any SimulatorManaging,
        executor: any CleanupExecuting,
        preferences: any PreferencesStoring,
        runningApplications: any RunningApplicationsProviding,
        analytics: any Analytics,
        errorReporter: any ErrorReporting,
        appBundleIdentifier: String,
        minimumTemporaryAgeInDays: Int = TemporaryItemsPolicy.defaultMinimumAgeInDays,
        now: @escaping () -> Date = Date.init,
        activationDebounce: Duration = .seconds(2),
        measurementCacheDuration: TimeInterval = 60
    ) {
        let selected = catalog.categories.filter { preferences.isSelected($0.id) ?? $0.isEnabledByDefault }

        self.catalog = catalog
        self.measurer = measurer
        self.snapshotReader = SimulatorSnapshotReader(simulators: simulators, locations: catalog.locations)
        self.simulators = simulators
        self.executor = executor
        self.preferences = preferences
        self.runningApplications = runningApplications
        self.reporter = CleanupOutcomeReporter(analytics: analytics, errorReporter: errorReporter)
        self.temporaryPolicy = TemporaryItemsPolicy(
            minimumAgeInDays: minimumTemporaryAgeInDays,
            appBundleIdentifier: appBundleIdentifier
        )
        self.minimumTemporaryAgeInDays = minimumTemporaryAgeInDays
        self.appBundleIdentifier = appBundleIdentifier
        self.now = now
        self.activationDebounce = activationDebounce
        self.measurementCacheDuration = measurementCacheDuration
        self.categories = catalog.categories
        self.rows = Dictionary(uniqueKeysWithValues: catalog.categories.map { ($0.id, .measuring) })
        self.selectedIDs = Set(selected.map(\.id))
    }

    // MARK: - Public Methods

    /// Measures every category again, cancelling a measurement still running.
    func refresh() async {
        // The measurement after a cleanup covers it; nothing is measured while it runs.
        guard phase.allowsMeasurement else { return }

        await startMeasurement(keepingValues: false)
    }

    /// The menu bar icon's periodic measurement (C40): skipped while another complete measurement
    /// or a cleanup runs, and it keeps each row's last value until the new one arrives, so the size
    /// in the menu bar never drops and climbs back. It replaces a category measurement.
    func measureInBackground() async {
        guard !isMeasuringAll, phase.allowsMeasurement else { return }

        await startMeasurement(keepingValues: true)
    }

    /// The live measurement (C40 · tempo real): only `ids`, selected or not, keeping every value
    /// until the new one arrives and without running `simctl`. It never runs over another
    /// measurement, a confirmation or a cleanup, nor before the first complete measurement.
    func measureCategories(_ ids: Set<CleanupCategoryID>) async {
        guard !ids.isEmpty, categoryMeasurementAvailability == .available else { return }

        await startMeasurement(keepingValues: true, only: ids)
    }

    /// Opening or activating the window: ignored while measuring or cleaning, a burst measures
    /// once after a short pause, and a measurement younger than the cache is reused (R1).
    func windowDidActivate() async {
        guard shouldMeasureOnActivation else { return }

        activationTask?.cancel()

        let debounce = activationDebounce
        let task = Task {
            try? await Task.sleep(for: debounce)

            // A measurement may have started, or finished, during the pause.
            guard !Task.isCancelled, shouldMeasureOnActivation else { return }

            await refresh()
        }

        activationTask = task
        await task.value
    }

    /// The selection is frozen while a plan is confirmed or cleaned, and an unavailable row
    /// cannot be picked.
    func canToggle(_ id: CleanupCategoryID) -> Bool {
        phase.allowsMeasurement && !isUnavailable(id)
    }

    /// A new minimum age from Settings (D7): it reaches the plan being confirmed and the next ones,
    /// and measures again. Items younger than the age the user sees are never removed (R11).
    func setMinimumTemporaryAgeInDays(_ days: Int) async {
        guard days != minimumTemporaryAgeInDays else { return }

        minimumTemporaryAgeInDays = days
        temporaryPolicy = TemporaryItemsPolicy(minimumAgeInDays: days, appBundleIdentifier: appBundleIdentifier)
        lastMeasuredAt = nil

        if case let .confirming(plan) = phase {
            phase = .confirming(CleanupPlan(categories: plan.categories, minimumTemporaryAgeInDays: days))
        }

        await refresh()
    }

    /// "Encerrar agora" on the Simulator-open notice: quits Simulator.app, shuts the default set
    /// down and measures again. A failure only leaves the notice on screen.
    func shutDownSimulators() async {
        guard phase.allowsMeasurement else { return }

        _ = await runningApplications.terminateSimulator()
        try? await simulators.shutdownAll(in: .default)
        await refresh()
    }

    func toggle(_ id: CleanupCategoryID) {
        guard canToggle(id) else { return }

        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }

        preferences.setSelected(id, selectedIDs.contains(id))
        updateIdlePhase()
    }

    /// Xcode and the simulators are checked again first. Settings Xcode no longer blocks come
    /// back through a new measurement. Plans with attention or danger, or with a warning for
    /// running apps, wait for a confirmation (R5, F31).
    func requestClean() async {
        guard canClean else { return }

        let current = currentRestrictions()
        let isUnblocked = categories.contains { category in
            rows[category.id] == .unavailable(.xcodeIsRunning) && !current.isBlocked(category.id)
        }

        if isUnblocked {
            await refresh()

            guard canClean else { return }
        } else {
            apply(current)
        }

        let plan = CleanupPlan(categories: plannedCategories, minimumTemporaryAgeInDays: minimumTemporaryAgeInDays)

        guard !plan.categories.isEmpty else {
            updateIdlePhase()
            return
        }

        if cleanNeedsConfirmation {
            phase = .confirming(plan)
        } else {
            await run(plan)
        }
    }

    func confirm() async {
        guard case let .confirming(plan) = phase else { return }

        await run(plan)
    }

    /// Leaves a confirmation, or stops a running cleanup between items.
    func cancel() {
        switch phase {
        case .confirming:
            phase = idlePhase()

        case let .cleaning(progress):
            phase = .cancelling(freedBytes: progress.freedBytes)
            cleanupTask?.cancel()

        default:
            break
        }
    }

    /// Runs again only the categories that failed; they were already confirmed.
    func retryFailed() async {
        guard let report = phase.report else { return }

        apply(currentRestrictions())

        let failedIDs = Set(report.failedCategoryIDs)
        let plan = CleanupPlan(
            categories: categories.filter { failedIDs.contains($0.id) && !isUnavailable($0.id) },
            minimumTemporaryAgeInDays: minimumTemporaryAgeInDays
        )

        guard !plan.categories.isEmpty else { return }

        await run(plan)
    }

    func dismissReport() {
        guard phase.report != nil else { return }

        phase = idlePhase()
    }

    // MARK: - Private Methods

    private func isUnavailable(_ id: CleanupCategoryID) -> Bool {
        rows[id]?.isUnavailable ?? false
    }

    /// The generation is taken here, before the new task starts, so a cancelled measurement can
    /// never end the newer one's state. `ids` is `nil` for a complete measurement.
    private func startMeasurement(keepingValues: Bool, only ids: Set<CleanupCategoryID>? = nil) async {
        measurementGeneration += 1
        measurementTask?.cancel()
        // Running from here on, before the task starts, so an activation never measures again.
        isMeasuring = true
        isMeasuringAll = ids == nil

        let generation = measurementGeneration
        let task = Task { await measure(generation: generation, keepingValues: keepingValues, only: ids) }

        measurementTask = task
        await task.value
    }

    private func measure(generation: Int, keepingValues: Bool, only ids: Set<CleanupCategoryID>?) async {
        // Before reading anything: an earlier start only makes "already covered" less likely.
        let startedAt = now()

        measurementCount += 1

        defer {
            // A newer measurement owns the state from here on.
            if generation == measurementGeneration {
                isMeasuring = false
                isMeasuringAll = false
                updateIdlePhase()
            }
        }

        guard let snapshot = await snapshot(for: ids) else { return }

        hasBootedSimulators = snapshot.hasBootedDevices
        // Cheap, and Xcode may have opened since the last complete measurement.
        restrictions = currentRestrictions()

        let plan = CategoryRowState.plan(for: categoriesToPlan(ids), restrictions: restrictions, snapshot: snapshot)

        rows.merge(plan.rows) { CategoryRowState.refreshed(current: $0, planned: $1, keepingValues: keepingValues) }

        updateIdlePhase()

        let filters = TemporaryFilters.forMeasurement(
            policy: temporaryPolicy,
            knownUDIDs: snapshot.knownUDIDs,
            now: now()
        )

        do {
            try await measurer.measure(plan.toMeasure, filters: filters) { size in
                rows[size.categoryID] = CategoryRowState(size: size)
                measurementStarts[size.categoryID] = startedAt
                updateIdlePhase()
            }
        } catch {
            return
        }

        guard ids == nil else { return }

        lastMeasuredAt = now()
        lastSnapshot = snapshot
    }

    /// Every category, or `ids` plus the ones whose Xcode block changed since their row was planned,
    /// so the rows always match the restrictions just published (C40 · tempo real).
    private func categoriesToPlan(_ ids: Set<CleanupCategoryID>?) -> [CleanupCategory] {
        guard let ids else { return categories }

        return categories.filter { category in
            let isShownBlocked = rows[category.id] == .unavailable(.xcodeIsRunning)

            return ids.contains(category.id) || isShownBlocked != restrictions.isBlocked(category.id)
        }
    }

    /// A complete measurement lists the simulators; a category one reuses the last listing.
    private func snapshot(for ids: Set<CleanupCategoryID>?) async -> SimulatorSnapshot? {
        guard ids != nil else { return await snapshotReader.read() }

        return lastSnapshot
    }

    /// Simulators count as active when Simulator.app runs or the last listing saw a booted device.
    private func currentRestrictions() -> CleanupRestrictions {
        CleanupRestrictions(
            categories: categories,
            isXcodeRunning: runningApplications.isXcodeRunning,
            areSimulatorsActive: hasBootedSimulators || runningApplications.isSimulatorRunning
        )
    }

    private func apply(_ restrictions: CleanupRestrictions) {
        self.restrictions = restrictions

        for id in restrictions.blockedCategoryIDs {
            rows[id] = .unavailable(.xcodeIsRunning)
        }
    }

    /// Nothing is measured while the executor runs; the measurement after it updates everything.
    private func run(_ plan: CleanupPlan) async {
        activationTask?.cancel()
        measurementTask?.cancel()
        phase = .cleaning(CleanupProgress(totalCategories: plan.categories.count))
        reporter.started()

        let task = Task { await executor.execute(plan) { event in self.apply(event) } }

        cleanupTask = task

        let report = await task.value

        cleanupTask = nil
        reporter.finished(report, for: plan)

        let wasDenied = report.failedResults.contains { $0.outcome == .failed(.permissionDenied) }
        phase = report.outcome != .cancelled && wasDenied ? .permissionDenied(report) : .finished(report)

        // The report stays until dismissed while the sizes are measured again (R1).
        await refresh()
    }

    private func apply(_ event: CleanupEvent) {
        guard case var .cleaning(progress) = phase else { return }

        progress.apply(event)
        phase = .cleaning(progress)
    }

    private func updateIdlePhase() {
        switch phase {
        case .measuring, .ready, .nothingSelected, .nothingToClean:
            phase = idlePhase()

        default:
            break
        }
    }

    private func idlePhase() -> CleanerPhase {
        let planned = plannedCategories

        if isMeasuring, planned.contains(where: { rows[$0.id] == .measuring }) {
            return .measuring(first: lastMeasuredAt == nil)
        }

        guard !planned.isEmpty else { return .nothingSelected }

        // Resetting the preferences frees no space but is still something to do.
        let hasReset = planned.contains(where: \.operation.resetsPreferences)

        return totalBytes == 0 && !hasReset ? .nothingToClean : .ready
    }

}
