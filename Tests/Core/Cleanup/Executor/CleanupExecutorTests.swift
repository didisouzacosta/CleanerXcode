//
//  CleanupExecutorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Every collaborator is a fake that logs its calls: nothing touches the disk, `simctl`, the
/// running apps or the preferences.
@MainActor
struct CleanupExecutorTests {

    // MARK: - Private Properties

    /// Kept as a suite property so the folder lives until the test ends.
    private let fixture: TemporaryDirectoryFixture
    private let locations: CleanupLocations
    private let catalog: CleanupCatalog
    private let log = CallLog()

    // MARK: - Initializers

    init() throws {
        let fixture = try TemporaryDirectoryFixture()
        let locations = try CleanupLocations(
            home: fixture.makeDirectory("home"),
            userTemporary: fixture.makeDirectory("T"),
            systemTemporary: fixture.makeDirectory("tmp"),
            varTemporary: fixture.makeDirectory("var/tmp")
        )

        self.fixture = fixture
        self.locations = locations
        self.catalog = CleanupCatalog(locations: locations)
    }

    // MARK: - Public Methods

    @Test
    func runsTheStepsInTheFixedOrderAndRestartsTheServiceAfterADirectCoreSimulatorRemoval() async {
        let remover = RemoverSpy(log: log, outcomes: ["Caches": [(10, .removed)]])
        let executor = makeExecutor(remover: remover)

        let report = await executor.execute(plan(
            .removeDerivedData,
            .clearSimulatorData,
            .removeOldSimulators,
            .resetXcodePreferences,
            .clearSimulatorCaches
        )) { _ in }

        #expect(log.calls == [
            "terminateSimulator",
            "shutdownAll default",
            "eraseAll",
            "list default",
            "deleteUnavailable",
            "remove remove-derived-data DerivedData delete",
            "reset com.apple.dt.Xcode",
            "remove clear-simulator-caches Caches delete",
            "remove clear-simulator-caches Temp delete",
            "remove clear-simulator-caches CoreSimulator delete",
            "restartService",
        ])
        #expect(report.outcome == .success)
    }

    @Test
    func neverClosesSimulatorsNorRestartsTheServiceWithoutSimulatorWork() async {
        let report = await makeExecutor().execute(plan(.removeDerivedData, .removeCaches)) { _ in }

        #expect(!log.calls.contains("terminateSimulator"))
        #expect(!log.calls.contains { $0.hasPrefix("shutdownAll") })
        #expect(!log.calls.contains("restartService"))
        #expect(report.outcome == .success)
    }

    @Test
    func doesNotRestartTheServiceWhenNothingWasRemovedFromCoreSimulator() async {
        _ = await makeExecutor().execute(plan(.clearSimulatorCaches)) { _ in }

        #expect(log.calls.contains("shutdownAll default"))
        #expect(!log.calls.contains("restartService"))
    }

    @Test
    func oneFailedItemMakesThePartialFailureThatIsNeverReportedAsSuccess() async {
        let remover = RemoverSpy(log: log, outcomes: [
            "DerivedData": [(100, .removed), (0, .failed(.permissionDenied))],
            "com.apple.dt.Xcode": [(50, .removed)],
        ])

        let report = await makeExecutor(remover: remover).execute(plan(.removeDerivedData, .removeCaches)) { _ in }

        #expect(report.outcome == .partialFailure)
        #expect(report.failedResults.map(\.outcome) == [.failed(.permissionDenied)])
        #expect(report.freedBytes == 150)
    }

    @Test
    func cancellingBetweenItemsReportsCancelledWithWhatWasAlreadyFreed() async {
        let remover = RemoverSpy(
            log: log,
            outcomes: ["DerivedData": [(100, .removed)]],
            cancelsAfter: .removeDerivedData
        )
        let executor = makeExecutor(remover: remover)
        let cleanupPlan = plan(.removeDerivedData, .removeCaches, .clearSimulatorCaches)

        let report = await Task { await executor.execute(cleanupPlan) { _ in } }.value

        #expect(report.outcome == .cancelled)
        #expect(report.freedBytes == 100)
        #expect(!log.calls.contains { $0.contains("remove-caches") })
        #expect(!log.calls.contains("restartService"))
    }

    @Test
    func reChecksXcodeRightBeforeItsOwnSettingsAndRefusesWhileItRuns() async {
        let executor = makeExecutor(applications: RunningApplicationsFake(log: log, isXcodeRunning: true))

        let report = await executor
            .execute(plan(.resetXcodePreferences, .removeXcodeUserData, .removeDerivedData)) { _ in }

        #expect(!log.calls.contains { $0.hasPrefix("reset") })
        #expect(!log.calls.contains { $0.contains("remove-xcode-user-data") })
        #expect(report.failedResults.map(\.outcome) == [
            .failed(.blockedByRunningApp(.xcode)),
            .failed(.blockedByRunningApp(.xcode)),
        ])
        #expect(log.calls.contains { $0.contains("remove-derived-data") })
    }

    @Test
    func aSimulatorThatDoesNotCloseFailsOnlyTheSimulatorCategories() async {
        let executor = makeExecutor(applications: RunningApplicationsFake(log: log, quits: false))

        let report = await executor
            .execute(plan(.removeDerivedData, .clearSimulatorData, .clearSimulatorCaches)) { _ in }

        #expect(!log.calls.contains("shutdownAll default"))
        #expect(!log.calls.contains("eraseAll"))
        #expect(!log.calls.contains { $0.contains("clear-simulator-caches") })
        #expect(log.calls.contains { $0.contains("remove-derived-data") })
        #expect(report.failedResults.map(\.categoryID) == [.clearSimulatorData, .clearSimulatorCaches])
        #expect(report.failedResults.allSatisfy { $0.outcome == .failed(.blockedByRunningApp(.simulator)) })
    }

    @Test
    func aCancelWhileTheSimulatorIsClosingIsReportedAsCancelled() async {
        let refused = makeExecutor(applications: RunningApplicationsFake(
            log: log,
            quits: false,
            cancelsWhileQuitting: true
        ))
        let quit = makeExecutor(applications: RunningApplicationsFake(
            log: log,
            quits: true,
            cancelsWhileQuitting: true
        ))
        let cleanupPlan = plan(.clearSimulatorData)

        let refusedReport = await Task { await refused.execute(cleanupPlan) { _ in } }.value
        let quitReport = await Task { await quit.execute(cleanupPlan) { _ in } }.value

        #expect(refusedReport.outcome == .cancelled && quitReport.outcome == .cancelled)
        #expect(refusedReport.failedResults.isEmpty && quitReport.failedResults.isEmpty)
        #expect(!log.calls.contains("eraseAll"))
        #expect(!log.calls.contains("shutdownAll default"), "A cancelled run never shuts the simulators down.")
    }

    @Test
    func aFailedSimctlStepFailsItsCategoryAndTheOthersGoOn() async {
        let simulators = SimulatorManagerSpy(
            log: log,
            failures: ["eraseAll": .commandFailed(exitCode: 149, summary: "busy")]
        )

        let report = await makeExecutor(simulators: simulators).execute(plan(
            .clearSimulatorData,
            .removeDerivedData
        )) { _ in }

        #expect(report.failedResults.map(\.outcome) == [.failed(.commandFailed(exitCode: 149, summary: "busy"))])
        #expect(log.calls.contains { $0.contains("remove-derived-data") })
    }

    @Test
    func simctlStepsReportTheSpaceTheyFreed() async {
        let scanner = SequencedScannerStub(sizes: ["Devices": [9_000, 1_000]])
        let simulators = SimulatorManagerSpy(log: log, unavailableSizes: [300, 200])

        let report = await makeExecutor(simulators: simulators, scanner: scanner)
            .execute(plan(.clearSimulatorData, .removeOldSimulators)) { _ in }

        #expect(report.results.map(\.bytes) == [8_000, 500])
        #expect(report.freedBytes == 8_500)
    }

    @Test
    func clearsEachExistingAuxiliarySetThroughSimctlAndThenItsLeftovers() async throws {
        try fixture.makeDirectory("home/Library/Developer/XCTestDevices")
        try fixture.makeDirectory("home/Library/Developer/Xcode/UserData/Previews/Simulator Devices")

        _ = await makeExecutor().execute(plan(.clearAuxiliaryDeviceSets)) { _ in }

        #expect(log.calls == [
            "terminateSimulator",
            "shutdownAll default",
            "shutdownAll XCTestDevices",
            "deleteAll XCTestDevices",
            "shutdownAll Simulator Devices",
            "deleteAll Simulator Devices",
            "remove clear-auxiliary-device-sets XCTestDevices delete",
            "remove clear-auxiliary-device-sets Previews delete",
            "remove clear-auxiliary-device-sets IB Support delete",
            "remove clear-auxiliary-device-sets XCPGDevices delete",
        ])
    }

    @Test
    func temporaryCategoriesUseTheirFiltersAndTurnBusyItemsIntoSkipped() async throws {
        let remover = RemoverSpy(log: log, outcomes: ["tmp": [(0, .failed(.inUse)), (5, .removed)]])

        let report = await makeExecutor(remover: remover).execute(plan(.clearTemporaryFiles)) { _ in }
        let filter = try #require(remover.filters[.clearTemporaryFiles])
        let launchd = try fixture.makeDirectory("tmp/com.apple.launchd.abc")

        #expect(report.outcome == .success)
        #expect(report.results.map(\.outcome).contains(.skipped(.inUse)))
        #expect(!filter(launchd))
        #expect(log.calls.filter { $0.contains("clear-temporary-files") }.count == 3)
    }

    @Test
    func theOrphanCategoryFailsWhenTheSimulatorsCannotBeListed() async {
        let simulators = SimulatorManagerSpy(log: log, failures: ["list default": .toolUnavailable])

        let report = await makeExecutor(simulators: simulators).execute(plan(.clearOrphanSimulatorTemp)) { _ in }

        #expect(report.failedResults.map(\.outcome) == [.failed(.toolUnavailable)])
        #expect(!log.calls.contains { $0.contains("clear-orphan-simulator-temp") })
    }

    /// Every root and set handed to the remover or to `simctl` lives in the test's own home and
    /// temporary folders, so nothing can reach `/Library/Developer/CoreSimulator`.
    @Test
    func onlyEverTouchesRootsAndSetsFromTheCatalogLocations() async throws {
        try fixture.makeDirectory("home/Library/Developer/XCTestDevices")
        let remover = RemoverSpy(log: log)
        let simulators = SimulatorManagerSpy(log: log)
        let everything = CleanupPlan(categories: catalog.categories, minimumTemporaryAgeInDays: 3)
        let base = fixture.url.path(percentEncoded: false)

        _ = await makeExecutor(remover: remover, simulators: simulators).execute(everything) { _ in }

        let touched = remover.roots + simulators.setPaths

        #expect(!remover.roots.isEmpty && !simulators.setPaths.isEmpty)
        #expect(touched.allSatisfy { $0.hasPrefix(base) })
    }

    @Test
    func aStepThatFinishedKeepsItsResultWhenCancelledWhileMeasuringAfterIt() async throws {
        try fixture.makeDirectory("home/Library/Developer/XCTestDevices")
        let eraseExecutor = makeExecutor(scanner: SequencedScannerStub(
            sizes: ["Devices": [9_000]],
            cancelsOnCall: ["Devices": 2]
        ))
        let setExecutor = makeExecutor(scanner: SequencedScannerStub(cancelsOnCall: ["XCTestDevices": 2]))
        let erasePlan = plan(.clearSimulatorData)
        let setPlan = plan(.clearAuxiliaryDeviceSets)

        let eraseReport = await Task { await eraseExecutor.execute(erasePlan) { _ in } }.value
        let setReport = await Task { await setExecutor.execute(setPlan) { _ in } }.value

        #expect(eraseReport.outcome == .cancelled)
        #expect(eraseReport.results.map(\.outcome) == [.removed])
        #expect(setReport.outcome == .cancelled)
        #expect(setReport.results.map(\.outcome) == [.removed])
    }

    @Test(arguments: ["shutdownAll XCTestDevices", "deleteAll XCTestDevices"])
    func keepsTheLeftoversOfAnAuxiliarySetWhoseSimctlStepFailed(failingCall: String) async throws {
        try fixture.makeDirectory("home/Library/Developer/XCTestDevices")
        try fixture.makeDirectory("home/Library/Developer/Xcode/UserData/Previews/Simulator Devices")
        let simulators = SimulatorManagerSpy(
            log: log,
            failures: [failingCall: .commandFailed(exitCode: 1, summary: "busy")]
        )

        let report = await makeExecutor(simulators: simulators).execute(plan(.clearAuxiliaryDeviceSets)) { _ in }

        #expect(!log.calls.contains("remove clear-auxiliary-device-sets XCTestDevices delete"))
        #expect(log.calls.contains("remove clear-auxiliary-device-sets Previews delete"))
        #expect(log.calls.contains("remove clear-auxiliary-device-sets XCPGDevices delete"))
        #expect(report.failedResults.count == 1)
    }

    @Test
    func aCancelledRunStillRestartsTheServiceAfterADirectCoreSimulatorRemoval() async {
        let remover = RemoverSpy(log: log, outcomes: ["Caches": [(10, .removed)]], cancelsAfter: .clearSimulatorCaches)
        let executor = makeExecutor(remover: remover)
        let cleanupPlan = plan(.clearSimulatorCaches, .clearTemporaryFiles)

        let report = await Task { await executor.execute(cleanupPlan) { _ in } }.value

        #expect(report.outcome == .cancelled)
        #expect(log.calls.last == "restartService")
    }

    @Test
    func aCancelSwallowedOnTheLastItemStillEndsCancelled() async {
        let remover = RemoverSpy(log: log, outcomes: ["DerivedData": [(1, .removed)]], cancelsAfter: .removeDerivedData)
        let executor = makeExecutor(remover: remover)
        let cleanupPlan = plan(.removeDerivedData)

        let report = await Task { await executor.execute(cleanupPlan) { _ in } }.value

        #expect(report.outcome == .cancelled)
        #expect(report.freedBytes == 1)
    }

    @Test
    func anAlreadyCancelledRunNeverClosesTheSimulator() async {
        let executor = makeExecutor()
        let cleanupPlan = plan(.clearSimulatorData)

        let report = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await executor.execute(cleanupPlan) { _ in }
        }.value

        #expect(report.outcome == .cancelled)
        #expect(log.calls.isEmpty)
    }

    @Test
    func aCancelWhileListingUnavailableSimulatorsNeverDeletesThem() async {
        let simulators = SimulatorManagerSpy(log: log, failures: ["list default": .cancelled])

        let report = await makeExecutor(simulators: simulators).execute(plan(.removeOldSimulators)) { _ in }

        #expect(report.outcome == .cancelled)
        #expect(!log.calls.contains("deleteUnavailable"))
    }

    @Test
    func failedRestartsAndFailedDeletionsAreReportedAsFailures() async {
        let remover = RemoverSpy(log: log, outcomes: ["Caches": [(10, .removed)]])
        let simulators = SimulatorManagerSpy(log: log, failures: [
            "restartService": .permissionDenied,
            "deleteUnavailable": .commandFailed(exitCode: 2, summary: "no"),
        ])

        let report = await makeExecutor(remover: remover, simulators: simulators)
            .execute(plan(.removeOldSimulators, .clearSimulatorCaches)) { _ in }

        #expect(report.outcome == .partialFailure)
        #expect(report.failedResults.map(\.outcome) == [
            .failed(.commandFailed(exitCode: 2, summary: "no")),
            .failed(.permissionDenied),
        ])
    }

    @Test
    func emitsEveryStepAndItemAsItHappens() async {
        let remover = RemoverSpy(log: log, outcomes: ["DerivedData": [(1, .removed)]])

        var events: [CleanupEvent] = []

        _ = await makeExecutor(remover: remover).execute(plan(.removeDerivedData)) { events.append($0) }

        #expect(events == [
            .categoryStarted(.removeDerivedData),
            .itemFinished(CleanupItemResult(
                categoryID: .removeDerivedData,
                displayPath: "~/DerivedData/item-0",
                bytes: 1,
                outcome: .removed
            )),
        ])
    }

    // MARK: - Private Methods

    private func plan(_ ids: CleanupCategoryID...) -> CleanupPlan {
        CleanupPlan(categories: catalog.categories.filter { ids.contains($0.id) }, minimumTemporaryAgeInDays: 3)
    }

    private func makeExecutor(
        remover: RemoverSpy? = nil,
        simulators: SimulatorManagerSpy? = nil,
        scanner: SequencedScannerStub = SequencedScannerStub(),
        applications: RunningApplicationsFake? = nil
    ) -> CleanupExecutor {
        let log = log

        return CleanupExecutor(
            locations: locations,
            remover: remover ?? RemoverSpy(log: log),
            simulators: simulators ?? SimulatorManagerSpy(log: log),
            scanner: scanner,
            runningApplications: applications ?? RunningApplicationsFake(log: log),
            makeResetter: { PreferencesResetterSpy(log: log, domain: $0) },
            appBundleIdentifier: "app.Cleaner"
        )
    }

}
