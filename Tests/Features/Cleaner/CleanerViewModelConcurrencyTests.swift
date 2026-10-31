//
//  CleanerViewModelConcurrencyTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Measurements that overlap each other, activations and cleanups, and the less common branches of
/// a measurement. Gated fakes make every interleaving deterministic.
@MainActor
struct CleanerViewModelConcurrencyTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))
    private let log = CallLog()
    private let analytics = AnalyticsStub()

    private var derivedData: URL {
        catalog[.removeDerivedData].targets[0].root
    }

    // MARK: - Public Methods

    /// The cancelled measurement must not end the newer one's state.
    @Test(.timeLimit(.minutes(1)))
    func aSupersededMeasurementLeavesTheStateToTheNewerOne() async {
        let simulators = GatedSimulatorManager()
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner, simulators: simulators, selected: [.removeDerivedData])

        var simulatorArrivals = simulators.arrivals.stream.makeAsyncIterator()
        var scanArrivals = scanner.arrivals.stream.makeAsyncIterator()

        let first = Task { await viewModel.refresh() }
        _ = await simulatorArrivals.next()
        let second = Task { await viewModel.refresh() }
        _ = await scanArrivals.next()
        await first.value

        #expect(viewModel.phase == .measuring(first: true))

        scanner.release()
        await second.value

        #expect(viewModel.phase == .ready)
        #expect(viewModel.rows[.removeDerivedData] == .measured(4_000))
    }

    @Test(.timeLimit(.minutes(1)))
    func measuringAgainIsNotTheFirstMeasurement() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner, selected: [.removeDerivedData])

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()
        scanner.release()
        await viewModel.refresh()
        _ = await arrivals.next()
        scanner.close()

        let again = Task { await viewModel.refresh() }
        _ = await arrivals.next()

        #expect(viewModel.phase == .measuring(first: false))

        scanner.release()
        await again.value

        #expect(viewModel.phase == .ready)
    }

    @Test(.timeLimit(.minutes(1)))
    func anActivationDuringAMeasurementDoesNotRestartIt() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner, selected: [.removeDerivedData])

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        let measuring = Task { await viewModel.refresh() }
        _ = await arrivals.next()
        await viewModel.windowDidActivate()
        scanner.release()
        await measuring.value

        #expect(viewModel.measurementCount == 1)
        #expect(viewModel.rows[.removeDerivedData] == .measured(4_000))
    }

    /// The launch fires a measurement and an activation in no fixed order.
    @Test(.timeLimit(.minutes(1)))
    func aMeasurementStartedDuringTheDebounceIsNotRestarted() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner, selected: [.removeDerivedData], debounce: .milliseconds(300))

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        let activation = Task { await viewModel.windowDidActivate() }
        await Task.yield()
        let measuring = Task { await viewModel.refresh() }
        _ = await arrivals.next()
        await activation.value
        scanner.release()
        await measuring.value

        #expect(viewModel.measurementCount == 1)
        #expect(viewModel.rows[.removeDerivedData] == .measured(4_000))
    }

    /// The measurement counts as running from `refresh()` on, before its task starts, so an
    /// activation in between never measures again (N13).
    @Test(.timeLimit(.minutes(1)))
    func aRefreshCountsAsMeasuringBeforeItsTaskStarts() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner, selected: [.removeDerivedData])

        let measuring = Task { await viewModel.refresh() }
        await Task.yield()

        #expect(viewModel.isMeasuring)

        scanner.release()
        await measuring.value

        #expect(!viewModel.isMeasuring)
    }

    @Test(.timeLimit(.minutes(1)))
    func aMeasurementFinishedDuringTheDebounceIsReused() async {
        let viewModel = makeViewModel(selected: [.removeDerivedData], debounce: .milliseconds(300))

        let activation = Task { await viewModel.windowDidActivate() }
        await Task.yield()
        await viewModel.refresh()
        await activation.value

        #expect(viewModel.measurementCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func aDirectRefreshNeverRunsDuringACleanup() async {
        let executor = CleanupExecutorSpy(waitsForCancellation: true)
        let viewModel = makeViewModel(
            executor: executor,
            selected: [.removeDerivedData],
            sizes: [.removeDerivedData: 1]
        )
        await viewModel.refresh()

        let cleaning = Task { await viewModel.requestClean() }

        var started = executor.started.stream.makeAsyncIterator()
        _ = await started.next()
        await viewModel.refresh()

        #expect(viewModel.measurementCount == 1)

        viewModel.cancel()
        await cleaning.value
    }

    @Test(.timeLimit(.minutes(1)))
    func nothingIsMeasuredWhileACleanupRuns() async {
        var now = Date(timeIntervalSince1970: 1_000)

        let executor = CleanupExecutorSpy(waitsForCancellation: true)
        let viewModel = makeViewModel(
            executor: executor,
            selected: [.removeDerivedData],
            sizes: [.removeDerivedData: 1],
            now: { now }
        )
        await viewModel.refresh()

        let cleaning = Task { await viewModel.requestClean() }

        var started = executor.started.stream.makeAsyncIterator()
        _ = await started.next()
        now += 120
        await viewModel.windowDidActivate()

        #expect(viewModel.measurementCount == 1, "Activations wait for the cleanup to end.")

        viewModel.cancel()
        await cleaning.value

        #expect(viewModel.measurementCount == 2, "The cleanup measures again when it ends.")
    }

    /// F31: the simulators are only shut down with consent.
    @Test
    func aSafePlanThatClosesOpenSimulatorsAsksFirst() async {
        let applications = RunningApplicationsFake(log: log)
        let executor = CleanupExecutorSpy()
        let viewModel = makeViewModel(
            executor: executor,
            applications: applications,
            selected: [.removeDerivedData, .clearSimulatorCaches],
            sizes: [.removeDerivedData: 1, .clearSimulatorCaches: 1]
        )
        await viewModel.refresh()
        applications.isSimulatorRunning = true

        await viewModel.requestClean()

        #expect(viewModel.phase.isConfirming)
        #expect(viewModel.restrictions.warnings[.clearSimulatorCaches] == .simulatorsWillClose)
        #expect(executor.plans.isEmpty)
    }

    @Test
    func aSafePlanWithNothingOpenRunsRightAway() async {
        let executor = CleanupExecutorSpy()
        let viewModel = makeViewModel(
            executor: executor,
            selected: [.removeDerivedData, .clearSimulatorCaches],
            sizes: [.removeDerivedData: 1, .clearSimulatorCaches: 1]
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        #expect(executor.plans.count == 1)
    }

    @Test
    func closingXcodeBeforeCleaningBringsItsSettingsBack() async {
        let applications = RunningApplicationsFake(log: log, isXcodeRunning: true)
        let viewModel = makeViewModel(
            applications: applications,
            selected: [.removeDerivedData, .resetXcodePreferences, .removeXcodeUserData],
            sizes: [.removeDerivedData: 1, .removeXcodeUserData: 5]
        )
        await viewModel.refresh()
        applications.isXcodeRunning = false

        await viewModel.requestClean()

        guard case let .confirming(plan) = viewModel.phase else {
            Issue.record("Expected a confirmation, got \(viewModel.phase)")
            return
        }

        #expect(plan.categories.map(\.id) == [.removeDerivedData, .resetXcodePreferences, .removeXcodeUserData])
        #expect(!viewModel.rows.values.contains(.unavailable(.xcodeIsRunning)))
    }

    /// R10: the caches cannot be removed without shutting the simulators down first.
    @Test
    func withoutTheXcodeToolsTheSimulatorCachesAreUnavailableToo() async {
        let executor = CleanupExecutorSpy()
        let viewModel = makeViewModel(
            executor: executor,
            simulators: SimulatorManagerStub(failingSets: [.default: .toolUnavailable]),
            selected: [.removeDerivedData, .clearSimulatorCaches],
            sizes: [.removeDerivedData: 1, .clearSimulatorCaches: 50]
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        #expect(viewModel.rows[.clearSimulatorCaches] == .unavailable(.toolsUnavailable))
        #expect(executor.plans.map { $0.categories.map(\.id) } == [[.removeDerivedData]])
    }

    @Test
    func aListingThatFailsForAnotherReasonOnlyFailsTheUnavailableSimulators() async {
        let failure = CleanupError.commandFailed(exitCode: 1, summary: "busy")
        let viewModel = makeViewModel(simulators: SimulatorManagerStub(failingSets: [.default: failure]))

        await viewModel.refresh()

        #expect(viewModel.rows[.removeOldSimulators] == .failed(failure))
        #expect(viewModel.rows[.clearOrphanSimulatorTemp] == .unavailable(.simulatorListUnavailable))
        #expect(viewModel.rows[.clearSimulatorData] != .unavailable(.toolsUnavailable))
    }

    @Test
    func aFailedAuxiliarySetMakesOnlyTheOrphanFoldersUnavailable() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let locations = try CleanupLocations(
            home: fixture.makeDirectory("home"),
            userTemporary: fixture.makeDirectory("T"),
            systemTemporary: fixture.makeDirectory("tmp"),
            varTemporary: fixture.makeDirectory("var/tmp")
        )
        let xcTest = try fixture.makeDirectory("home/Library/Developer/XCTestDevices")
        let simulators = SimulatorManagerStub(failingSets: [.custom(xcTest): .commandFailed(exitCode: 1, summary: "")])
        let viewModel = makeViewModel(catalog: CleanupCatalog(locations: locations), simulators: simulators)

        await viewModel.refresh()

        #expect(viewModel.rows[.clearOrphanSimulatorTemp] == .unavailable(.simulatorListUnavailable))
        #expect(viewModel.rows[.clearSimulatorData] != .unavailable(.toolsUnavailable))
    }

    @Test
    func aBootedSimulatorAlsoCountsAsActive() async {
        let simulators = SimulatorManagerStub(devices: [.default: ["BOOTED"]], bootedUDIDs: ["BOOTED"])
        let viewModel = makeViewModel(simulators: simulators)

        await viewModel.refresh()

        #expect(viewModel.restrictions.warnings[.clearSimulatorCaches] == .simulatorsWillClose)
    }

    @Test
    func aRunWhereEverythingFailedIsReportedAsAFailure() async {
        let report = CleanupReport(results: [
            CleanupItemResult(categoryID: .removeDerivedData, displayPath: "~/DD", bytes: 0, outcome: .failed(.inUse)),
        ])
        let viewModel = makeViewModel(
            executor: CleanupExecutorSpy(reports: [report]),
            selected: [.removeDerivedData],
            sizes: [.removeDerivedData: 1]
        )
        await viewModel.refresh()

        await viewModel.requestClean()

        #expect(viewModel.phase == .finished(report))
        #expect(analytics.events.last { $0.name == "cleaner" }?.properties["result"] as? String == "failure")
    }

    // MARK: - Private Methods

    private func makeViewModel(
        catalog customCatalog: CleanupCatalog? = nil,
        scanner customScanner: (any DiskUsageScanning)? = nil,
        executor: CleanupExecutorSpy = CleanupExecutorSpy(),
        simulators: any SimulatorManaging = SimulatorManagerStub(),
        applications: RunningApplicationsFake? = nil,
        selected: Set<CleanupCategoryID>? = nil,
        sizes: [CleanupCategoryID: Int64] = [:],
        now: @escaping () -> Date = Date.init,
        debounce: Duration = .zero
    ) -> CleanerViewModel {
        let catalog = customCatalog ?? self.catalog
        let preferences = InMemoryPreferencesStore()

        var scannerSizes: [URL: Int64] = [:]

        for (id, size) in sizes {
            scannerSizes[catalog[id].targets[0].root] = size
        }

        if let selected {
            for category in catalog.categories {
                preferences.setSelected(category.id, selected.contains(category.id))
            }
        }

        return CleanerViewModel(
            catalog: catalog,
            measurer: CategorySizeMeasurer(scanner: customScanner ?? DiskUsageScannerStub(sizes: scannerSizes)),
            simulators: simulators,
            executor: executor,
            preferences: preferences,
            runningApplications: applications ?? RunningApplicationsFake(log: log),
            analytics: analytics,
            errorReporter: ErrorReporterStub(),
            appBundleIdentifier: "app.Cleaner",
            now: now,
            activationDebounce: debounce
        )
    }

}

extension CleanerPhase {

    // MARK: - Test Helpers

    var isConfirming: Bool {
        if case .confirming = self {
            true
        } else {
            false
        }
    }

}
