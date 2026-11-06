//
//  CleanerViewModelBackgroundTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The measurement the menu bar icon starts in the background (C40): it keeps each row's last
/// value until the new one arrives, and never runs over another measurement or a cleanup.
@MainActor
struct CleanerViewModelBackgroundTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))
    private let log = CallLog()

    private var derivedData: URL {
        catalog[.removeDerivedData].targets[0].root
    }

    // MARK: - Public Methods

    /// With nothing measured yet, it looks like any first measurement.
    @Test(.timeLimit(.minutes(1)))
    func theFirstBackgroundMeasurementIsAnOrdinaryOne() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        let measuring = Task { await viewModel.measureInBackground() }
        _ = await arrivals.next()

        #expect(viewModel.phase == .measuring(first: true))
        #expect(viewModel.rows[.removeDerivedData] == .measuring)

        scanner.release()
        await measuring.value

        #expect(viewModel.phase == .ready)
        #expect(viewModel.rows[.removeDerivedData] == .measured(4_000))
    }

    /// Stale-while-revalidate: the label never drops and climbs back.
    @Test(.timeLimit(.minutes(1)))
    func measuringAgainInTheBackgroundKeepsTheLastValues() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        scanner.release()
        await viewModel.refresh()
        _ = await arrivals.next()
        scanner.close()
        scanner.setSize(9_000)

        let measuring = Task { await viewModel.measureInBackground() }
        _ = await arrivals.next()

        #expect(viewModel.rows[.removeDerivedData] == .measured(4_000))
        #expect(viewModel.phase == .ready)
        #expect(viewModel.totalBytes == 4_000)

        scanner.release()
        await measuring.value

        #expect(viewModel.rows[.removeDerivedData] == .measured(9_000))
        #expect(viewModel.measurementCount == 2)
    }

    /// The window's Refresh still shows that everything is being measured again.
    @Test(.timeLimit(.minutes(1)))
    func refreshingStillShowsTheRowsBeingMeasured() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        scanner.release()
        await viewModel.refresh()
        _ = await arrivals.next()
        scanner.close()

        let measuring = Task { await viewModel.refresh() }
        _ = await arrivals.next()

        #expect(viewModel.rows[.removeDerivedData] == .measuring)
        #expect(viewModel.phase == .measuring(first: false))

        scanner.release()
        await measuring.value
    }

    @Test(.timeLimit(.minutes(1)))
    func itNeverRunsOverAnotherMeasurement() async {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = makeViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        let measuring = Task { await viewModel.refresh() }
        _ = await arrivals.next()
        await viewModel.measureInBackground()
        scanner.release()
        await measuring.value

        #expect(viewModel.measurementCount == 1)
    }

    @Test
    func itNeverRunsDuringAConfirmation() async {
        let viewModel = makeViewModel(selected: [.removeArchives], sizes: [.removeArchives: 2_000])
        await viewModel.refresh()
        await viewModel.requestClean()

        await viewModel.measureInBackground()

        #expect(viewModel.phase.isConfirming)
        #expect(viewModel.measurementCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func itNeverRunsWhileCleaningOrCancelling() async {
        let executor = CleanupExecutorSpy(waitsForCancellation: true)
        let viewModel = makeViewModel(executor: executor, sizes: [.removeDerivedData: 1])
        await viewModel.refresh()

        let cleaning = Task { await viewModel.requestClean() }

        var started = executor.started.stream.makeAsyncIterator()
        _ = await started.next()
        await viewModel.measureInBackground()

        #expect(viewModel.measurementCount == 1, "Nothing is measured while cleaning.")

        viewModel.cancel()
        await viewModel.measureInBackground()

        #expect(viewModel.measurementCount == 1, "Nothing is measured while cancelling.")

        await cleaning.value

        #expect(viewModel.measurementCount == 2, "The cleanup measures again when it ends.")
    }

    /// A finished measurement from any origin postpones the next background one.
    @Test
    func aFinishedBackgroundMeasurementRecordsWhenItEnded() async {
        let viewModel = makeViewModel(now: { Date(timeIntervalSince1970: 1_000) })

        #expect(viewModel.lastMeasuredAt == nil)

        await viewModel.measureInBackground()

        #expect(viewModel.lastMeasuredAt == Date(timeIntervalSince1970: 1_000))
    }

    // MARK: - Private Methods

    private func makeViewModel(
        scanner customScanner: (any DiskUsageScanning)? = nil,
        executor: CleanupExecutorSpy = CleanupExecutorSpy(),
        selected: Set<CleanupCategoryID> = [.removeDerivedData],
        sizes: [CleanupCategoryID: Int64] = [:],
        now: @escaping () -> Date = Date.init
    ) -> CleanerViewModel {
        let preferences = InMemoryPreferencesStore()

        var scannerSizes: [URL: Int64] = [:]

        for (id, size) in sizes {
            scannerSizes[catalog[id].targets[0].root] = size
        }

        for category in catalog.categories {
            preferences.setSelected(category.id, selected.contains(category.id))
        }

        return CleanerViewModel(
            catalog: catalog,
            measurer: CategorySizeMeasurer(scanner: customScanner ?? DiskUsageScannerStub(sizes: scannerSizes)),
            simulators: SimulatorManagerStub(),
            executor: executor,
            preferences: preferences,
            runningApplications: RunningApplicationsFake(log: log),
            analytics: AnalyticsStub(),
            errorReporter: ErrorReporterStub(),
            appBundleIdentifier: "app.Cleaner",
            now: now,
            activationDebounce: .zero
        )
    }

}
