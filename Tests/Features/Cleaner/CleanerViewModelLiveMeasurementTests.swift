//
//  CleanerViewModelLiveMeasurementTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Measuring only the categories whose folders changed (C40 · tempo real, R4, R8, R9): it keeps
/// the other rows and the phase, never runs `simctl`, never runs over another measurement or a
/// cleanup, and any complete measurement replaces it.
@MainActor
struct CleanerViewModelLiveMeasurementTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))
    private let log = CallLog()
    private let clock = ManualDateClock()
    private let simulators = CountingSimulatorManager()

    private var derivedData: URL {
        catalog[.removeDerivedData].targets[0].root
    }

    // MARK: - Public Methods

    /// Nothing to keep before the first complete measurement, which covers every change.
    @Test
    func beforeTheFirstCompleteMeasurementNothingIsMeasured() async {
        let viewModel = makeViewModel()

        #expect(viewModel.categoryMeasurementAvailability == .notReady)

        await viewModel.measureCategories([.removeDerivedData])

        #expect(viewModel.measurementCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func onlyTheChangedCategoryIsMeasuredAgainKeepingTheRest() async throws {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = try await measuredViewModel(scanner: scanner, selected: [.removeDerivedData, .removeArchives])
        let completedAt = viewModel.lastMeasuredAt
        let listings = simulators.listCount

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        clock.advance(by: 30)
        scanner.setSize(9_000)

        let measuring = Task { await viewModel.measureCategories([.removeDerivedData]) }
        _ = await arrivals.next()

        #expect(viewModel.rows[.removeDerivedData] == .measured(4_000))
        #expect(viewModel.phase == .ready)
        #expect(viewModel.totalBytes == 4_000)

        scanner.release()
        await measuring.value

        #expect(viewModel.rows[.removeDerivedData] == .measured(9_000))
        #expect(viewModel.rows[.removeArchives] == .empty)
        #expect(viewModel.measurementStarts[.removeDerivedData] == clock.now)
        #expect(viewModel.measurementStarts[.removeArchives] == clock.now.addingTimeInterval(-30), "Not measured.")
        #expect(viewModel.lastMeasuredAt == completedAt, "Only a complete measurement postpones the loop.")
        #expect(simulators.listCount == listings, "No simctl.")
        #expect(viewModel.measurementCount == 2)
        #expect(viewModel.phase == .ready)
    }

    /// The owner's choice (C40 · tempo real, R8 reversed): every observed category is live, selected
    /// or not.
    @Test(.timeLimit(.minutes(1)))
    func anUnselectedCategoryIsMeasuredToo() async throws {
        let scanner = GatedScannerStub(gatedRoot: catalog[.removeArchives].targets[0].root, size: 2_000)
        let viewModel = try await measuredViewModel(scanner: scanner, selected: [.removeDerivedData])

        clock.advance(by: 30)
        scanner.setSize(6_000)
        scanner.release()
        await viewModel.measureCategories([.removeArchives])

        #expect(viewModel.rows[.removeArchives] == .measured(6_000))
        #expect(viewModel.measurementStarts[.removeArchives] == clock.now)
        #expect(viewModel.measurementCount == 2)
    }

    @Test
    func itNeverRunsDuringAConfirmation() async throws {
        let viewModel = try await measuredViewModel(selected: [.removeArchives], sizes: [.removeArchives: 2_000])

        await viewModel.requestClean()

        #expect(viewModel.phase.isConfirming)
        #expect(viewModel.categoryMeasurementAvailability == .busy)

        await viewModel.measureCategories([.removeArchives])

        #expect(viewModel.measurementCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func itNeverRunsWhileCleaningOrCancelling() async throws {
        let executor = CleanupExecutorSpy(waitsForCancellation: true)
        let viewModel = try await measuredViewModel(executor: executor, sizes: [.removeDerivedData: 1])
        let cleaning = Task { await viewModel.requestClean() }

        var started = executor.started.stream.makeAsyncIterator()
        _ = await started.next()

        #expect(viewModel.isModifyingFiles)
        #expect(viewModel.categoryMeasurementAvailability == .notReady)

        await viewModel.measureCategories([.removeDerivedData])
        viewModel.cancel()

        #expect(viewModel.isModifyingFiles)
        #expect(viewModel.categoryMeasurementAvailability == .notReady)

        await viewModel.measureCategories([.removeDerivedData])

        #expect(viewModel.measurementCount == 1)

        await cleaning.value

        #expect(!viewModel.isModifyingFiles)
    }

    @Test(.timeLimit(.minutes(1)))
    func itNeverRunsOverAnotherMeasurement() async throws {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = try await measuredViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        let refreshing = Task { await viewModel.refresh() }
        _ = await arrivals.next()

        #expect(viewModel.categoryMeasurementAvailability == .busy)

        await viewModel.measureCategories([.removeDerivedData])

        #expect(viewModel.measurementCount == 2)

        scanner.release()
        await refreshing.value
    }

    /// A complete measurement always wins: the category one is cancelled and its result dropped.
    @Test(.timeLimit(.minutes(1)))
    func refreshingReplacesACategoryMeasurement() async throws {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = try await measuredViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        clock.advance(by: 30)

        let measuring = Task { await viewModel.measureCategories([.removeDerivedData]) }
        _ = await arrivals.next()
        clock.advance(by: 10)

        let refreshing = Task { await viewModel.refresh() }
        _ = await arrivals.next()

        #expect(viewModel.rows[.removeDerivedData] == .measuring)

        scanner.release()
        await measuring.value
        await refreshing.value

        #expect(viewModel.measurementCount == 3)
        #expect(viewModel.measurementStarts[.removeDerivedData] == clock.now, "The refresh's value.")
        #expect(viewModel.phase == .ready)
    }

    @Test(.timeLimit(.minutes(1)))
    func activatingTheWindowStillMeasuresEverything() async throws {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = try await measuredViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        clock.advance(by: 120)

        let measuring = Task { await viewModel.measureCategories([.removeDerivedData]) }
        _ = await arrivals.next()

        let activating = Task { await viewModel.windowDidActivate() }
        _ = await arrivals.next()

        #expect(viewModel.measurementCount == 3)

        scanner.release()
        await measuring.value
        await activating.value

        #expect(viewModel.lastMeasuredAt == clock.now)
    }

    @Test(.timeLimit(.minutes(1)))
    func theBackgroundMeasurementStillMeasuresEverything() async throws {
        let scanner = GatedScannerStub(gatedRoot: derivedData, size: 4_000)
        let viewModel = try await measuredViewModel(scanner: scanner)

        var arrivals = scanner.arrivals.stream.makeAsyncIterator()

        let measuring = Task { await viewModel.measureCategories([.removeDerivedData]) }
        _ = await arrivals.next()

        let background = Task { await viewModel.measureInBackground() }
        _ = await arrivals.next()

        #expect(viewModel.measurementCount == 3)

        scanner.release()
        await measuring.value
        await background.value
    }

    /// Xcode opened since the last complete measurement: its settings are blocked at once, without
    /// reading the disk.
    @Test
    func xcodeOpenedSinceTheLastMeasurementBlocksItsSettings() async throws {
        let applications = RunningApplicationsFake(log: log)
        let viewModel = try await measuredViewModel(selected: [.removeXcodeUserData], applications: applications)
        let completedStart = viewModel.measurementStarts[.removeXcodeUserData]

        applications.isXcodeRunning = true
        clock.advance(by: 30)
        await viewModel.measureCategories([.removeXcodeUserData])

        #expect(viewModel.rows[.removeXcodeUserData] == .unavailable(.xcodeIsRunning))
        #expect(viewModel.measurementStarts[.removeXcodeUserData] == completedStart)
    }

    /// The rows always match the published restrictions: Xcode opened, so its preferences reset,
    /// which is not measured, is blocked by any category measurement.
    @Test
    func xcodeOpeningBlocksTheRowsTheRestrictionsBlock() async throws {
        let applications = RunningApplicationsFake(log: log)
        let viewModel = try await measuredViewModel(applications: applications)

        #expect(viewModel.rows[.resetXcodePreferences] == .empty)

        applications.isXcodeRunning = true
        await viewModel.measureCategories([.removeDerivedData])

        #expect(viewModel.restrictions.isXcodeRunning)
        #expect(viewModel.rows[.resetXcodePreferences] == .unavailable(.xcodeIsRunning))
        #expect(viewModel.rows[.removeXcodeUserData] == .unavailable(.xcodeIsRunning))
    }

    @Test
    func xcodeClosingFreesTheRowsItBlocked() async throws {
        let applications = RunningApplicationsFake(log: log, isXcodeRunning: true)
        let viewModel = try await measuredViewModel(applications: applications)

        #expect(viewModel.rows[.resetXcodePreferences] == .unavailable(.xcodeIsRunning))

        applications.isXcodeRunning = false
        await viewModel.measureCategories([.removeDerivedData])

        #expect(!viewModel.restrictions.isXcodeRunning)
        #expect(viewModel.rows[.resetXcodePreferences] == .empty)
        #expect(viewModel.rows[.removeXcodeUserData] == .empty, "Measured again from the disk.")
    }

    // MARK: - Private Methods

    /// After one complete measurement; a gated scanner is left closed again.
    private func measuredViewModel(
        scanner: GatedScannerStub? = nil,
        executor: CleanupExecutorSpy = CleanupExecutorSpy(),
        selected: Set<CleanupCategoryID> = [.removeDerivedData],
        sizes: [CleanupCategoryID: Int64] = [:],
        applications: RunningApplicationsFake? = nil
    ) async throws -> CleanerViewModel {
        let viewModel = makeViewModel(
            scanner: scanner,
            executor: executor,
            selected: selected,
            sizes: sizes,
            applications: applications
        )

        if let scanner {
            var arrivals = scanner.arrivals.stream.makeAsyncIterator()

            scanner.release()
            await viewModel.refresh()
            _ = await arrivals.next()
            scanner.close()
        } else {
            await viewModel.refresh()
        }

        try #require(viewModel.categoryMeasurementAvailability == .available)

        return viewModel
    }

    private func makeViewModel(
        scanner: (any DiskUsageScanning)? = nil,
        executor: CleanupExecutorSpy = CleanupExecutorSpy(),
        selected: Set<CleanupCategoryID> = [.removeDerivedData],
        sizes: [CleanupCategoryID: Int64] = [:],
        applications: RunningApplicationsFake? = nil
    ) -> CleanerViewModel {
        let preferences = InMemoryPreferencesStore()
        let clock = clock

        var scannerSizes: [URL: Int64] = [:]

        for (id, size) in sizes {
            scannerSizes[catalog[id].targets[0].root] = size
        }

        for category in catalog.categories {
            preferences.setSelected(category.id, selected.contains(category.id))
        }

        return CleanerViewModel(
            catalog: catalog,
            measurer: CategorySizeMeasurer(scanner: scanner ?? DiskUsageScannerStub(sizes: scannerSizes)),
            simulators: simulators,
            executor: executor,
            preferences: preferences,
            runningApplications: applications ?? RunningApplicationsFake(log: log),
            analytics: AnalyticsStub(),
            errorReporter: ErrorReporterStub(),
            appBundleIdentifier: "app.Cleaner",
            now: { clock.now },
            activationDebounce: .zero
        )
    }

}
