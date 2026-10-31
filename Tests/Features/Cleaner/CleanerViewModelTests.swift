//
//  CleanerViewModelTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Every collaborator is a fake: nothing is measured on disk, removed, run or reported for real.
@MainActor
struct CleanerViewModelTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))
    private let log = CallLog()
    private let analytics = AnalyticsStub()
    private let errorReporter = ErrorReporterStub()

    private var cleanerEvent: AnalyticsEvent? {
        analytics.events.last { $0.name == "cleaner" }
    }

    // MARK: - Public Methods

    @Test
    func startsMeasuringAndThenShowsTheEstimatedTotalOfTheSelectedCategories() async {
        let viewModel = makeViewModel(sizes: [.removeDerivedData: 3_000, .removeCaches: 2_000, .removeArchives: 9_000])

        #expect(viewModel.phase == .measuring(first: true))

        await viewModel.refresh()

        #expect(viewModel.rows[.removeDerivedData] == .measured(3_000))
        #expect(viewModel.rows[.removeArchives] == .measured(9_000))
        #expect(viewModel.totalBytes == 5_000, "Archives is off by default, so it does not count.")
        #expect(viewModel.phase == .ready)
        #expect(viewModel.canClean)
    }

    @Test
    func togglingKeepsTheChoiceAndRecomputesTheTotal() async {
        let preferences = InMemoryPreferencesStore()
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 3_000, .removeArchives: 9_000],
            preferences: preferences
        )
        await viewModel.refresh()

        viewModel.toggle(.removeArchives)

        #expect(viewModel.totalBytes == 12_000)
        #expect(preferences.isSelected(.removeArchives) == true)
    }

    @Test
    func nothingSelectedAndNothingToCleanDisableTheButton() async {
        let viewModel = makeViewModel(sizes: [:], preferences: selecting([.removeDerivedData]))
        await viewModel.refresh()

        #expect(viewModel.phase == .nothingToClean)
        #expect(!viewModel.canClean)

        viewModel.toggle(.removeDerivedData)

        #expect(viewModel.phase == .nothingSelected)
        #expect(!viewModel.canClean)
    }

    /// Resetting the preferences frees no space but is still something to do.
    @Test
    func theResetAloneCanStillBeRequested() async {
        let viewModel = makeViewModel(sizes: [:], preferences: selecting([.resetXcodePreferences]))
        await viewModel.refresh()

        #expect(viewModel.phase == .ready)
    }

    @Test
    func withoutTheXcodeToolsTheSimulatorCategoriesAreUnavailableAndTheOthersWork() async {
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 1_000],
            simulators: SimulatorManagerStub(failingSets: [.default: .toolUnavailable])
        )
        await viewModel.refresh()

        for id: CleanupCategoryID in [
            .clearSimulatorData,
            .removeOldSimulators,
            .clearAuxiliaryDeviceSets,
            .clearOrphanSimulatorTemp,
        ] {
            #expect(viewModel.rows[id] == .unavailable(.toolsUnavailable))
        }
        #expect(viewModel.rows[.removeDerivedData] == .measured(1_000))
        #expect(viewModel.phase == .ready)
    }

    @Test
    func withXcodeOpenItsSettingsAreUnavailableAndDerivedDataWarns() async {
        let applications = RunningApplicationsFake(log: log, isXcodeRunning: true)
        let viewModel = makeViewModel(sizes: [.removeDerivedData: 1_000], applications: applications)
        await viewModel.refresh()

        #expect(viewModel.rows[.resetXcodePreferences] == .unavailable(.xcodeIsRunning))
        #expect(viewModel.rows[.removeXcodeUserData] == .unavailable(.xcodeIsRunning))
        #expect(viewModel.restrictions.warnings[.removeDerivedData] == .xcodeIsRunning)
    }

    @Test
    func aSafePlanRunsRightAwayAndTheReportStaysUntilDismissed() async {
        let report = CleanupReport(results: [result(.removeDerivedData, bytes: 3_000, .removed)])
        let executor = CleanupExecutorSpy(reports: [report])
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 3_000],
            preferences: selecting([.removeDerivedData]),
            executor: executor
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        #expect(executor.plans.map { $0.categories.map(\.id) } == [[.removeDerivedData]])
        #expect(viewModel.phase == .finished(report))
        #expect(errorReporter.stages == [.cleanupStarted, .cleanupFinished])

        viewModel.dismissReport()

        #expect(viewModel.phase == .ready)
    }

    @Test
    func attentionOrDangerousItemsNeedAConfirmationThatCanBeCancelled() async {
        let executor = CleanupExecutorSpy()
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 1_000, .removeArchives: 2_000],
            preferences: selecting([.removeDerivedData, .removeArchives]),
            executor: executor
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        guard case let .confirming(plan) = viewModel.phase else {
            Issue.record("Expected a confirmation, got \(viewModel.phase)")
            return
        }

        #expect(plan.categories.map(\.id) == [.removeDerivedData, .removeArchives])

        viewModel.cancel()

        #expect(viewModel.phase == .ready)
        #expect(executor.plans.isEmpty)

        await viewModel.requestClean()
        await viewModel.confirm()

        #expect(executor.plans.count == 1)
    }

    @Test
    func requestingAgainReChecksXcodeAndLeavesItsSettingsOutOfThePlan() async {
        let applications = RunningApplicationsFake(log: log)
        let executor = CleanupExecutorSpy()
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 1_000],
            preferences: selecting([.removeDerivedData, .resetXcodePreferences]),
            executor: executor,
            applications: applications
        )
        await viewModel.refresh()
        applications.isXcodeRunning = true

        await viewModel.requestClean()

        // DerivedData now warns that Xcode is open, so the plan waits for a confirmation.
        #expect(viewModel.phase == .confirming(CleanupPlan(categories: [catalog[.removeDerivedData]])))
        #expect(executor.plans.isEmpty)
        #expect(viewModel.rows[.resetXcodePreferences] == .unavailable(.xcodeIsRunning))
    }

    @Test(.timeLimit(.minutes(1)))
    func showsTheProgressOfTheRunningCleanup() async {
        let item = result(.removeDerivedData, bytes: 700, .removed)
        let executor = CleanupExecutorSpy(
            events: [.categoryStarted(.removeDerivedData), .itemFinished(item)],
            waitsForCancellation: true
        )
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 1_000],
            preferences: selecting([.removeDerivedData]),
            executor: executor
        )
        await viewModel.refresh()

        let cleaning = Task { await viewModel.requestClean() }

        var started = executor.started.stream.makeAsyncIterator()
        _ = await started.next()

        #expect(viewModel.phase == .cleaning(CleanupProgress(
            totalCategories: 1,
            startedCategories: 1,
            currentCategory: .removeDerivedData,
            finishedItems: 1,
            freedBytes: 700
        )))

        viewModel.cancel()

        #expect(viewModel.phase == .cancelling)

        await cleaning.value

        guard case let .finished(report) = viewModel.phase else {
            Issue.record("Expected a report, got \(viewModel.phase)")
            return
        }

        #expect(report.outcome == .cancelled)
        #expect(report.freedBytes == 700)
        #expect(cleanerEvent?.properties["result"] as? String == "cancelled")
    }

    @Test
    func aPartialFailureIsReportedOnceAndNeverShownAsSuccess() async {
        let report = CleanupReport(results: [
            result(.removeDerivedData, bytes: 2_000_000_000, .removed),
            result(.removeCaches, bytes: 0, .failed(.inUse)),
        ])
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 1, .removeCaches: 1],
            preferences: selecting([.removeDerivedData, .removeCaches]),
            executor: CleanupExecutorSpy(reports: [report])
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        #expect(viewModel.phase == .finished(report))
        #expect(cleanerEvent?.properties["result"] as? String == "partial_failure")
        #expect(
            cleanerEvent?.properties["freed_bucket"] as? String == "1-10GB",
            "The bucket comes from the real report."
        )
        #expect(analytics.events.map(\.name).contains("cleaner_partial_failure"))
        #expect(errorReporter.failures == [
            .cleanupFailed(failedCategories: ["remove-caches"], errorKinds: [.inUse], totalCategories: 2),
        ])
    }

    @Test
    func aPermissionFailureLeadsToThePermissionState() async {
        let report = CleanupReport(results: [result(.removeCaches, bytes: 0, .failed(.permissionDenied))])
        let viewModel = makeViewModel(
            sizes: [.removeCaches: 1],
            preferences: selecting([.removeCaches]),
            executor: CleanupExecutorSpy(reports: [report])
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        #expect(viewModel.phase == .permissionDenied(report))
    }

    @Test
    func retryingRunsOnlyTheCategoriesThatFailed() async {
        let first = CleanupReport(results: [
            result(.removeDerivedData, bytes: 10, .removed),
            result(.removeCaches, bytes: 0, .failed(.inUse)),
        ])
        let executor = CleanupExecutorSpy(reports: [first, CleanupReport(results: [])])
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 1, .removeCaches: 1],
            preferences: selecting([.removeDerivedData, .removeCaches]),
            executor: executor
        )
        await viewModel.refresh()
        await viewModel.requestClean()

        await viewModel.retryFailed()

        #expect(executor.plans.map { $0.categories.map(\.id) } == [
            [.removeDerivedData, .removeCaches],
            [.removeCaches],
        ])
    }

    @Test
    func measuresAgainAfterACleanup() async {
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 1],
            preferences: selecting([.removeDerivedData]),
            executor: CleanupExecutorSpy(reports: [CleanupReport(results: [])])
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        #expect(viewModel.measurementCount == 2)
    }

    @Test
    func activatingTheWindowUsesTheRecentMeasurementAndCoalescesBursts() async {
        var now = Date(timeIntervalSince1970: 1_000)

        let viewModel = makeViewModel(sizes: [:], now: { now }, debounce: .milliseconds(100))

        async let first: Void = viewModel.windowDidActivate()
        async let second: Void = viewModel.windowDidActivate()
        _ = await (first, second)

        #expect(viewModel.measurementCount == 1, "A burst of activations measures once.")

        now += 30
        await viewModel.windowDidActivate()

        #expect(viewModel.measurementCount == 1, "Within 60 s the last measurement is reused.")

        now += 31
        await viewModel.windowDidActivate()

        #expect(viewModel.measurementCount == 2)
    }

    /// "de 87,7 GB encontrados" counts every measured category, selected or not.
    @Test
    func countsWhatWasFoundAndHowManyCategoriesAreMeasured() async {
        let viewModel = makeViewModel(
            sizes: [.removeDerivedData: 3_000, .removeArchives: 9_000],
            preferences: selecting([.removeDerivedData])
        )

        #expect(viewModel.measuredCategoryCount == 0)

        await viewModel.refresh()

        #expect(viewModel.foundBytes == 12_000)
        #expect(viewModel.totalBytes == 3_000)
        #expect(viewModel.measuredCategoryCount == viewModel.categories.count)
        #expect(viewModel.selectedBytes(of: [catalog[.removeDerivedData], catalog[.removeArchives]]) == 3_000)
        #expect(viewModel.selectedBytes(of: [catalog[.removeArchives]]) == 0)
    }

    @Test
    func tellsWhichAppsAreOpenAndWhetherTheToolsAreMissing() async {
        let applications = RunningApplicationsFake(log: log, isXcodeRunning: true)
        applications.isSimulatorRunning = true

        let viewModel = makeViewModel(
            sizes: [:],
            simulators: SimulatorManagerStub(failingSets: [.default: .toolUnavailable]),
            applications: applications
        )

        #expect(!viewModel.areSimulatorToolsUnavailable)

        await viewModel.refresh()

        #expect(viewModel.restrictions.isXcodeRunning)
        #expect(viewModel.restrictions.areSimulatorsActive)
        #expect(viewModel.areSimulatorToolsUnavailable)
    }

    /// The selection is frozen while a plan is confirmed or cleaned.
    @Test
    func theSelectionCannotChangeDuringAConfirmation() async {
        let preferences = selecting([.removeArchives])
        let viewModel = makeViewModel(sizes: [.removeArchives: 9_000], preferences: preferences)
        await viewModel.refresh()
        await viewModel.requestClean()

        #expect(!viewModel.canToggle(.removeArchives))

        viewModel.toggle(.removeArchives)

        #expect(viewModel.selectedIDs == [.removeArchives])
        #expect(preferences.isSelected(.removeArchives) == true)

        viewModel.cancel()

        #expect(viewModel.canToggle(.removeArchives))
    }

    @Test
    func anUnavailableCategoryCannotBeToggled() async {
        let applications = RunningApplicationsFake(log: log, isXcodeRunning: true)
        let viewModel = makeViewModel(sizes: [:], applications: applications)
        await viewModel.refresh()

        #expect(!viewModel.canToggle(.resetXcodePreferences))
        #expect(viewModel.canToggle(.removeDerivedData))
    }

    // MARK: - Private Methods

    private func makeViewModel(
        sizes: [CleanupCategoryID: Int64],
        preferences: InMemoryPreferencesStore = InMemoryPreferencesStore(),
        executor: CleanupExecutorSpy = CleanupExecutorSpy(),
        simulators: SimulatorManagerStub = SimulatorManagerStub(),
        applications: RunningApplicationsFake? = nil,
        now: @escaping () -> Date = Date.init,
        debounce: Duration = .zero
    ) -> CleanerViewModel {
        var scannerSizes: [URL: Int64] = [:]

        for (id, size) in sizes {
            if let root = catalog[id].targets.first?.root {
                scannerSizes[root] = size
            }
        }

        return CleanerViewModel(
            catalog: catalog,
            measurer: CategorySizeMeasurer(scanner: DiskUsageScannerStub(sizes: scannerSizes)),
            simulators: simulators,
            executor: executor,
            preferences: preferences,
            runningApplications: applications ?? RunningApplicationsFake(log: log),
            analytics: analytics,
            errorReporter: errorReporter,
            appBundleIdentifier: "app.Cleaner",
            now: now,
            activationDebounce: debounce
        )
    }

    /// Only the given categories are on.
    private func selecting(_ ids: Set<CleanupCategoryID>) -> InMemoryPreferencesStore {
        let store = InMemoryPreferencesStore()

        for category in catalog.categories {
            store.setSelected(category.id, ids.contains(category.id))
        }

        return store
    }

    private func result(
        _ id: CleanupCategoryID,
        bytes: Int64,
        _ outcome: CleanupItemResult.Outcome
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: bytes, outcome: outcome)
    }

}
