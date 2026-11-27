//
//  CleanupExecutor.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Runs a confirmed plan without ever needing a reboot (R10), in a fixed order:
/// 1. quit Simulator.app and `simctl shutdown all`, when a category works on simulators;
/// 2. the `simctl` steps (erase, delete unavailable, auxiliary sets);
/// 3. file removals and the preferences reset, in catalog order;
/// 4. restart the CoreSimulatorService, only after a direct removal inside CoreSimulator.
///
/// It orchestrates on the caller's actor (the main actor) while the disk and process work runs
/// in `@concurrent` services. Each result is reported as it happens, cancellation is checked
/// between items, and a cancelled run still returns a report with what was already freed (R7).
/// It never touches `/Library/Developer/CoreSimulator`: every root comes from the catalog.
struct CleanupExecutor {

    // MARK: - Private Properties

    private let locations: CleanupLocations
    private let remover: any FileRemoving
    private let simulators: any SimulatorManaging
    private let scanner: any DiskUsageScanning
    private let runningApplications: any RunningApplicationsProviding
    private let makeResetter: (String) -> any XcodePreferencesResetting
    private let appBundleIdentifier: String
    private let now: () -> Date

    // MARK: - Initializers

    init(
        locations: CleanupLocations,
        remover: any FileRemoving,
        simulators: any SimulatorManaging,
        scanner: any DiskUsageScanning = FileSystemSizeScanner(),
        runningApplications: any RunningApplicationsProviding,
        makeResetter: @escaping (String)
            -> any XcodePreferencesResetting = { UserDefaultsPreferencesResetter(domain: $0) },
        appBundleIdentifier: String,
        now: @escaping () -> Date = Date.init
    ) {
        self.locations = locations
        self.remover = remover
        self.simulators = simulators
        self.scanner = scanner
        self.runningApplications = runningApplications
        self.makeResetter = makeResetter
        self.appBundleIdentifier = appBundleIdentifier
        self.now = now
    }

    // MARK: - Private Static Methods

    private static func isSimctlStep(_ operation: CleanupOperation) -> Bool {
        switch operation {
        case .eraseAllSimulators, .deleteUnavailableSimulators, .clearDeviceSets: true
        default: false
        }
    }

    private static func path(of url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// Cancellation can arrive wrapped as `CleanupError.cancelled`; it always stops the run.
    private static func rethrowIfCancelled(_ error: any Error) throws {
        if CleanupError(error) == .cancelled {
            throw CancellationError()
        }
    }

    // MARK: - Public Methods

    func execute(_ plan: CleanupPlan, onEvent: @escaping (CleanupEvent) -> Void) async -> CleanupReport {
        let run = Run(onEvent: onEvent)

        var wasCancelled = false

        do {
            try await perform(plan, in: run)
            // A cancellation swallowed on the very last item still ends the run as cancelled (R7).
            try Task.checkCancellation()
        } catch {
            wasCancelled = true
        }

        // Files already removed from CoreSimulator need the restart even after a cancel (R10).
        await restartServiceIfNeeded(for: plan.categories, in: run)

        return CleanupReport(results: run.results, wasCancelled: wasCancelled)
    }

    // MARK: - Private Methods

    private func perform(_ plan: CleanupPlan, in run: Run) async throws {
        // An already cancelled run must not even ask Simulator.app to quit.
        try Task.checkCancellation()

        let unavailable = try await prepareSimulators(for: plan.categories, in: run)
        let simctlSteps = plan.categories.filter { Self.isSimctlStep($0.operation) }
        let otherSteps = plan.categories.filter { !Self.isSimctlStep($0.operation) }

        for category in simctlSteps + otherSteps {
            try Task.checkCancellation()
            run.emit(.categoryStarted(category.id))

            if let error = unavailable[category.id] {
                run.record(result(category.id, path: label(of: category), outcome: .failed(error)))
            } else if category.isBlockedWhileXcodeRuns, runningApplications.isXcodeRunning {
                // R5 was checked when the plan was confirmed; Xcode may have opened since then.
                run.record(result(
                    category.id,
                    path: label(of: category),
                    outcome: .failed(.blockedByRunningApp(.xcode))
                ))
            } else {
                try await clean(category, plan: plan, in: run)
            }
        }
    }

    /// Quits Simulator.app and shuts the default set down. When that fails, the categories that
    /// need it are returned with the error and skipped; the others still run.
    private func prepareSimulators(
        for categories: [CleanupCategory],
        in run: Run
    ) async throws -> [CleanupCategoryID: CleanupError] {
        let simulatorCategories = categories.filter(\.shutsDownSimulators)

        guard !simulatorCategories.isEmpty else { return [:] }

        run.emit(.closingSimulators)

        let didQuit = await runningApplications.terminateSimulator()

        try Task.checkCancellation()

        let failure: CleanupError?

        if didQuit {
            do {
                try await simulators.shutdownAll(in: .default)
                failure = nil
            } catch {
                try Self.rethrowIfCancelled(error)
                failure = CleanupError(error)
            }
        } else {
            failure = .blockedByRunningApp(.simulator)
        }

        guard let failure else { return [:] }

        return Dictionary(uniqueKeysWithValues: simulatorCategories.map { ($0.id, failure) })
    }

    private func clean(_ category: CleanupCategory, plan: CleanupPlan, in run: Run) async throws {
        switch category.operation {
        case let .removeContents(mode):
            try await removeContents(of: category, mode: mode, filter: { _ in true }, softened: false, in: run)

        case .removeTemporaryItems:
            let filter = TemporaryFilters.temporaryFiles(policy: temporaryPolicy(for: plan), now: now())
            try await removeContents(of: category, mode: .delete, filter: filter, softened: true, in: run)

        case .removeOrphanSimulatorTemp:
            try await removeOrphanSimulatorTemp(category, plan: plan, in: run)

        case .eraseAllSimulators:
            try await runSimctlStep(category, path: label(of: category), measuring: category.targets, in: run) {
                try await simulators.eraseAll()
            }

        case .deleteUnavailableSimulators:
            try await deleteUnavailableSimulators(category, in: run)

        case .clearDeviceSets:
            try await clearDeviceSets(category, in: run)

        case let .resetPreferences(domain):
            do {
                try makeResetter(domain).reset()
                run.record(result(category.id, path: domain, outcome: .removed))
            } catch {
                run.record(result(category.id, path: domain, outcome: .failed(CleanupError(error))))
            }
        }
    }

    private func removeContents(
        of category: CleanupCategory,
        targets: [CleanupTarget]? = nil,
        mode: RemovalMode,
        filter: @escaping @Sendable (URL) -> Bool,
        softened: Bool,
        in run: Run
    ) async throws {
        for target in targets ?? category.targets {
            try await remover
                .removeContents(of: target, categoryID: category.id, mode: mode, filter: filter) { result in
                    run.record(softened ? TemporaryItemsPolicy.softened(result) : result)
                }
        }
    }

    /// Without the full list of simulators nothing can be called an orphan, so a listing failure
    /// fails the category instead of guessing.
    private func removeOrphanSimulatorTemp(_ category: CleanupCategory, plan: CleanupPlan, in run: Run) async throws {
        let knownUDIDs: Set<String>

        do {
            knownUDIDs = try await OrphanSimulatorTempFinder.knownUDIDs(
                from: simulators,
                in: DeviceSet.all(in: locations)
            )
        } catch {
            try Self.rethrowIfCancelled(error)
            run.record(result(category.id, path: label(of: category), outcome: .failed(CleanupError(error))))
            return
        }

        let filter = TemporaryFilters.orphanSimulatorTemp(
            finder: OrphanSimulatorTempFinder(knownUDIDs: knownUDIDs),
            policy: temporaryPolicy(for: plan),
            now: now()
        )

        try await removeContents(of: category, mode: .delete, filter: filter, softened: true, in: run)
    }

    /// The freed space is what the unavailable devices took before the deletion; a listing that
    /// fails only loses that number.
    private func deleteUnavailableSimulators(_ category: CleanupCategory, in run: Run) async throws {
        let bytes: Int64

        do {
            let unavailable = try await simulators.listDevices(in: .default).filter { !$0.isAvailable }
            bytes = unavailable.reduce(0) { $0 + $1.sizeBytes }
        } catch {
            try Self.rethrowIfCancelled(error)
            bytes = 0
        }

        try await runSimctlStep(category, path: "simctl delete unavailable", knownBytes: bytes, in: run) {
            try await simulators.deleteUnavailable()
        }
    }

    /// Each auxiliary set that exists is shut down and emptied through `simctl`, then whatever is
    /// left in the catalog roots is removed. A root that is, or holds, a set whose step failed is
    /// left alone: removing a live set behind the service's back is what used to need a reboot.
    private func clearDeviceSets(_ category: CleanupCategory, in run: Run) async throws {
        var failedSetPaths: [String] = []

        for set in DeviceSet.all(in: locations).dropFirst() {
            guard case let .custom(folder) = set else { continue }

            try Task.checkCancellation()

            let didClear = try await runSimctlStep(
                category,
                path: locations.displayPath(for: folder),
                measuring: [CleanupTarget(root: folder)],
                in: run
            ) {
                try await simulators.shutdownAll(in: set)
                try await simulators.deleteAllDevices(in: set)
            }

            if !didClear {
                failedSetPaths.append(Self.path(of: folder))
            }
        }

        let safeTargets = category.targets.filter { target in
            let root = Self.path(of: target.root)
            return !failedSetPaths.contains { $0 == root || $0.hasPrefix(root + "/") }
        }

        try await removeContents(
            of: category,
            targets: safeTargets,
            mode: .delete,
            filter: { _ in true },
            softened: false,
            in: run
        )
    }

    /// One result per `simctl` step, and whether it succeeded. The freed space is either known up
    /// front or measured as the difference of the targets before and after. Once the step has
    /// happened its result is always recorded, even when the measurement after it is cancelled.
    @discardableResult
    private func runSimctlStep(
        _ category: CleanupCategory,
        path: String,
        measuring targets: [CleanupTarget] = [],
        knownBytes: Int64? = nil,
        in run: Run,
        step: () async throws -> Void
    ) async throws -> Bool {
        let before = try await size(of: targets)

        do {
            try await step()
        } catch {
            try Self.rethrowIfCancelled(error)
            run.record(result(category.id, path: path, outcome: .failed(CleanupError(error))))
            return false
        }

        let freed: Int64

        if let knownBytes {
            freed = knownBytes
        } else {
            do {
                freed = try await max(0, before - size(of: targets))
            } catch {
                run.record(result(category.id, path: path, outcome: .removed))
                throw error
            }
        }

        run.record(result(category.id, path: path, bytes: freed, outcome: .removed))
        return true
    }

    /// Runs after both a finished and a cancelled run. The restart is a single signal, so it is
    /// not subject to cancellation.
    private func restartServiceIfNeeded(for categories: [CleanupCategory], in run: Run) async {
        let restarting = categories.filter(\.restartsSimulatorService)

        guard let category = restarting.first(where: { run.removedSomething(in: $0.id) }) else { return }

        run.emit(.restartingSimulatorService)

        do {
            try await simulators.restartService()
        } catch {
            run.record(result(category.id, path: "CoreSimulatorService", outcome: .failed(CleanupError(error))))
        }
    }

    /// A target that cannot be measured counts 0, so a failed measurement never fails the step.
    private func size(of targets: [CleanupTarget]) async throws -> Int64 {
        var total: Int64 = 0

        for target in targets {
            do {
                total += try await scanner.allocatedSize(of: target)
            } catch {
                try Self.rethrowIfCancelled(error)
            }
        }

        return total
    }

    private func temporaryPolicy(for plan: CleanupPlan) -> TemporaryItemsPolicy {
        TemporaryItemsPolicy(minimumAgeInDays: plan.minimumTemporaryAgeInDays, appBundleIdentifier: appBundleIdentifier)
    }

    private func label(of category: CleanupCategory) -> String {
        category.targets.first.map { locations.displayPath(for: $0.root) } ?? category.id.rawValue
    }

    private func result(
        _ categoryID: CleanupCategoryID,
        path: String,
        bytes: Int64 = 0,
        outcome: CleanupItemResult.Outcome
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: categoryID, displayPath: path, bytes: bytes, outcome: outcome)
    }

    // MARK: - Nested Types

    /// The results of one run, reported to the caller as they arrive.
    private final class Run {

        // MARK: - Public Properties

        private(set) var results: [CleanupItemResult] = []

        // MARK: - Private Properties

        private let onEvent: (CleanupEvent) -> Void

        // MARK: - Initializers

        init(onEvent: @escaping (CleanupEvent) -> Void) {
            self.onEvent = onEvent
        }

        // MARK: - Public Methods

        func emit(_ event: CleanupEvent) {
            onEvent(event)
        }

        func record(_ result: CleanupItemResult) {
            results.append(result)
            onEvent(.itemFinished(result))
        }

        func removedSomething(in categoryID: CleanupCategoryID) -> Bool {
            results.contains { result in
                guard result.categoryID == categoryID else { return false }

                return result.outcome == .removed || result.outcome == .trashed
            }
        }

    }

}
