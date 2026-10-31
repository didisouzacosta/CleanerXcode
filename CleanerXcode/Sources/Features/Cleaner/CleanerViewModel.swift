//
//  CleanerViewModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Observation

/// The single window's state and intents (plan section 2.4). It measures on demand, never by
/// polling and never during a cleanup (R1); it asks before plans with attention or danger, or that
/// would close Xcode-related work or the simulators (R5, F31); it runs plans through the executor
/// and keeps the report on screen until the user dismisses it. Analytics and error reports only go
/// through their protocols, in `CleanupOutcomeReporter`.
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

    /// For tests: how many measurements started.
    @ObservationIgnored private(set) var measurementCount = 0

    /// Estimated (R2): clones and hard links can make the freed space differ.
    var totalBytes: Int64 {
        plannedCategories.reduce(0) { total, category in
            guard case let .measured(bytes) = rows[category.id] else { return total }

            return total + bytes
        }
    }

    var canClean: Bool {
        phase == .ready
    }

    /// The selected categories that go to the Trash, for the fixed notice and the confirmation.
    var trashBoundCategoryIDs: Set<CleanupCategoryID> {
        Set(plannedCategories.filter { $0.operation == .removeContents(.trash) }.map(\.id))
    }

    /// Every measured category, selected or not: "of 87.7 GB found".
    var foundBytes: Int64 {
        rows.values.reduce(0) { total, row in
            guard case let .measured(bytes) = row else { return total }

            return total + bytes
        }
    }

    /// For "9 of 15 categories measured".
    var measuredCategoryCount: Int {
        rows.values.count { $0 != .measuring }
    }

    var areSimulatorToolsUnavailable: Bool {
        rows.values.contains(.unavailable(.toolsUnavailable))
    }

    // MARK: - Private Properties

    private var plannedCategories: [CleanupCategory] {
        categories.filter { selectedIDs.contains($0.id) && !isUnavailable($0.id) }
    }

    private var shouldMeasureOnActivation: Bool {
        guard !isMeasuring, phase.allowsMeasurement else { return false }

        guard let lastMeasuredAt else { return true }

        return now().timeIntervalSince(lastMeasuredAt) >= measurementCacheDuration
    }

    private let catalog: CleanupCatalog
    private let measurer: CategorySizeMeasurer
    private let snapshotReader: SimulatorSnapshotReader
    private let executor: any CleanupExecuting
    private let preferences: any PreferencesStoring
    private let runningApplications: any RunningApplicationsProviding
    private let reporter: CleanupOutcomeReporter
    private let temporaryPolicy: TemporaryItemsPolicy
    private let minimumTemporaryAgeInDays: Int
    private let now: () -> Date
    private let activationDebounce: Duration
    private let measurementCacheDuration: TimeInterval

    @ObservationIgnored private var measurementTask: Task<Void, Never>?
    @ObservationIgnored private var activationTask: Task<Void, Never>?
    @ObservationIgnored private var cleanupTask: Task<CleanupReport, Never>?
    @ObservationIgnored private var measurementGeneration = 0
    @ObservationIgnored private var lastMeasuredAt: Date?
    @ObservationIgnored private var hasBootedSimulators = false
    /// For tests: a measurement is running or about to start.
    @ObservationIgnored private(set) var isMeasuring = false

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
        self.executor = executor
        self.preferences = preferences
        self.runningApplications = runningApplications
        self.reporter = CleanupOutcomeReporter(analytics: analytics, errorReporter: errorReporter)
        self.temporaryPolicy = TemporaryItemsPolicy(
            minimumAgeInDays: minimumTemporaryAgeInDays,
            appBundleIdentifier: appBundleIdentifier
        )
        self.minimumTemporaryAgeInDays = minimumTemporaryAgeInDays
        self.now = now
        self.activationDebounce = activationDebounce
        self.measurementCacheDuration = measurementCacheDuration
        self.categories = catalog.categories
        self.rows = Dictionary(uniqueKeysWithValues: catalog.categories.map { ($0.id, .measuring) })
        self.selectedIDs = Set(selected.map(\.id))
    }

    // MARK: - Public Methods

    /// Measures every category again, cancelling a measurement still running. The generation is
    /// taken here, before the new task starts, so a cancelled one can never end the newer state.
    func refresh() async {
        // The measurement after a cleanup covers it; nothing is measured while it runs.
        guard phase.allowsMeasurement else { return }

        measurementGeneration += 1
        measurementTask?.cancel()
        // Running from here on, before the task starts, so an activation never measures again.
        isMeasuring = true

        let generation = measurementGeneration
        let task = Task { await measure(generation: generation) }

        measurementTask = task
        await task.value
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

    /// The selected part of a section, for its header.
    func selectedBytes(of categories: [CleanupCategory]) -> Int64 {
        categories.reduce(0) { total, category in
            guard selectedIDs.contains(category.id), case let .measured(bytes) = rows[category.id] else {
                return total
            }

            return total + bytes
        }
    }

    /// The selection is frozen while a plan is confirmed or cleaned, and an unavailable row
    /// cannot be picked.
    func canToggle(_ id: CleanupCategoryID) -> Bool {
        phase.allowsMeasurement && !isUnavailable(id)
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

        if plan.categories.contains(where: { $0.risk != .safe || restrictions.warnings[$0.id] != nil }) {
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

        case .cleaning:
            phase = .cancelling
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
        if case .unavailable = rows[id] {
            true
        } else {
            false
        }
    }

    private func measure(generation: Int) async {
        measurementCount += 1

        defer {
            // A newer measurement owns the state from here on.
            if generation == measurementGeneration {
                isMeasuring = false
                updateIdlePhase()
            }
        }

        guard let snapshot = await snapshotReader.read() else { return }

        hasBootedSimulators = snapshot.hasBootedDevices
        restrictions = currentRestrictions()

        let plan = CategoryRowState.plan(for: categories, restrictions: restrictions, snapshot: snapshot)

        rows.merge(plan.rows) { _, new in new }
        updateIdlePhase()

        let filters = TemporaryFilters.forMeasurement(
            policy: temporaryPolicy,
            knownUDIDs: snapshot.knownUDIDs,
            now: now()
        )

        do {
            try await measurer.measure(plan.toMeasure, filters: filters) { size in
                rows[size.categoryID] = CategoryRowState(size: size)
                updateIdlePhase()
            }
        } catch {
            return
        }

        lastMeasuredAt = now()
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

        switch event {
        case let .categoryStarted(id):
            progress.startedCategories += 1
            progress.currentCategory = id

        case let .itemFinished(result):
            progress.finishedItems += 1

            if result.outcome == .removed {
                progress.freedBytes += result.bytes
            } else if result.outcome == .trashed {
                progress.trashedBytes += result.bytes
            }

        case .closingSimulators, .restartingSimulatorService:
            break
        }

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
        let hasReset = planned.contains { category in
            if case .resetPreferences = category.operation {
                true
            } else {
                false
            }
        }

        return totalBytes == 0 && !hasReset ? .nothingToClean : .ready
    }

}
