//
//  DemoCleanupTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct DemoCleanupTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: .inert)

    // MARK: - Public Methods

    @Test
    func scannerReturnsTheStateSize() async throws {
        let state = DemoDiskState()
        let scanner = DemoDiskScanner(state: state) { _ in .zero }
        let derivedData = try #require(category(.removeDerivedData).targets.first)

        let bytes = try await scanner.allocatedSize(of: derivedData)

        #expect(bytes == 33_800_000_000)
    }

    @Test
    func scannerMeasuresTheLeftoverAfterTheCleanup() async throws {
        let state = DemoDiskState()
        let scanner = DemoDiskScanner(state: state) { _ in .zero }
        let derivedData = try #require(category(.removeDerivedData).targets.first)

        _ = state.clean(derivedData)
        let bytes = try await scanner.allocatedSize(of: derivedData)

        #expect(bytes == 12_000_000)
    }

    @Test
    func scannerStaggersTheTargetsInTheirOrder() throws {
        let state = DemoDiskState()
        let first = try #require(category(.removeDerivedData).targets.first)
        let later = try #require(category(.removeXcodeUserData).targets.first)

        let firstDelay = DemoDiskScanner.staggeredDelay(for: first, in: state)
        let laterDelay = DemoDiskScanner.staggeredDelay(for: later, in: state)

        #expect(firstDelay < laterDelay)
        #expect(laterDelay <= .seconds(3))
    }

    @Test
    func executorReportsEachCategoryInOrder() async {
        let state = DemoDiskState()
        let executor = DemoCleanupExecutor(state: state, stepDelay: .zero)
        let plan = CleanupPlan(categories: [category(.removeDerivedData), category(.removeArchives)])

        var events: [CleanupEvent] = []

        let report = await executor.execute(plan) { events.append($0) }

        #expect(events == [
            .categoryStarted(.removeDerivedData),
            .itemFinished(CleanupItemResult(
                categoryID: .removeDerivedData,
                displayPath: "~/Library/Developer/Xcode/DerivedData",
                bytes: 33_800_000_000,
                outcome: .removed
            )),
            .categoryStarted(.removeArchives),
            .itemFinished(CleanupItemResult(
                categoryID: .removeArchives,
                displayPath: "~/Library/Developer/Xcode/Archives",
                bytes: 4_200_000_000,
                outcome: .trashed
            )),
        ])
        #expect(report.outcome == .success)
        #expect(report.freedBytes == 33_800_000_000)
        #expect(report.trashedBytes == 4_200_000_000)
    }

    /// The storyboard cleans Xcode, then Simulators, then User data, whatever the catalog order.
    @Test
    func executorCleansSectionBySection() async {
        let state = DemoDiskState()
        let executor = DemoCleanupExecutor(state: state, stepDelay: .zero)
        let plan = CleanupPlan(categories: [
            category(.removeArchives),
            category(.clearSimulatorCaches),
            category(.removeDerivedData),
        ])

        var started: [CleanupCategoryID] = []

        _ = await executor.execute(plan) { event in
            if case let .categoryStarted(id) = event {
                started.append(id)
            }
        }

        #expect(started == [.removeDerivedData, .clearSimulatorCaches, .removeArchives])
    }

    @Test
    func executorEmptiesTheCleanedTargets() async throws {
        let state = DemoDiskState()
        let executor = DemoCleanupExecutor(state: state, stepDelay: .zero)
        let archives = try #require(category(.removeArchives).targets.first)

        _ = await executor.execute(CleanupPlan(categories: [category(.removeArchives)])) { _ in }

        #expect(state.size(of: archives) == 0)
    }

    @Test
    func simulatorsAddUpTheUnavailableBytesWithNoneBooted() {
        let devices = DemoSimulatorManager().listDevices(in: .default)
        let unavailable = devices.filter { !$0.isAvailable }

        #expect(unavailable.reduce(0) { $0 + $1.sizeBytes } == DemoSimulatorManager.unavailableBytes)
        #expect(devices.contains { $0.state == .booted } == false)
    }

    @Test
    func emptyTargetIsSkippedAsMissing() async {
        let state = DemoDiskState(entries: [])
        let executor = DemoCleanupExecutor(state: state, stepDelay: .zero)

        let report = await executor.execute(CleanupPlan(categories: [category(.removeDerivedData)])) { _ in }

        #expect(report.results.map(\.outcome) == [.skipped(.notFound)])
        #expect(report.freedBytes == 0)
    }

    @Test
    func cancelledRunStopsBeforeTheNextCategory() async throws {
        let state = DemoDiskState()
        let executor = DemoCleanupExecutor(state: state, stepDelay: .zero)
        let plan = CleanupPlan(categories: [category(.removeDerivedData), category(.removeArchives)])
        let archives = try #require(category(.removeArchives).targets.first)

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }

            return await executor.execute(plan) { _ in }
        }

        let report = await task.value

        #expect(report.outcome == .cancelled)
        #expect(state.size(of: archives) == 4_200_000_000)
    }

    // MARK: - Private Methods

    private func category(_ id: CleanupCategoryID) -> CleanupCategory {
        guard let category = catalog.categories.first(where: { $0.id == id }) else {
            preconditionFailure("Missing category \(id)")
        }

        return category
    }

}
