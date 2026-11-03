//
//  SimulatorsViewModelTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The Simulators and Runtimes section (R8, R9): duplicates are only pre-selected, every deletion
/// asks first, and the exact UDIDs or runtime identifier reach `simctl`.
struct SimulatorsViewModelTests {

    // MARK: - Private Properties

    private let iOS272 = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
    private let iOS271 = "com.apple.CoreSimulator.SimRuntime.iOS-27-1"
    private let analytics = AnalyticsStub()

    private var recent: SimulatorDevice {
        device("A", type: "iPhone-17-Pro", runtime: iOS272, daysAgo: 2)
    }

    private var older: SimulatorDevice {
        device("B", type: "iPhone-17-Pro", runtime: iOS272, daysAgo: 38)
    }

    private var other: SimulatorDevice {
        device("C", type: "iPad-Pro-13", runtime: iOS271, daysAgo: 12)
    }

    private var runtimes: [SimulatorRuntime] {
        [runtime("R2", iOS272, deletable: false), runtime("R1", iOS271, deletable: true)]
    }

    // MARK: - Public Methods

    @Test
    func startsIdleAndLoadsTheDevicesTheRuntimesAndTheDuplicates() async {
        let viewModel = makeViewModel(SimulatorsServiceSpy(devices: [recent, older, other], runtimes: runtimes))

        #expect(viewModel.phase == .idle)

        await viewModel.load()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.devices.map(\.udid) == ["A", "B", "C"])
        #expect(viewModel.runtimes.map(\.identifier) == ["R2", "R1"])
        #expect(viewModel.duplicateUDIDs == ["B"], "The most recent one is suggested to stay.")
        #expect(viewModel.dependentCount(of: runtimes[0]) == 2)
        #expect(viewModel.dependentCount(of: runtimes[1]) == 1)
    }

    @Test
    func nothingToShowIsEmpty() async {
        let viewModel = makeViewModel(SimulatorsServiceSpy())

        await viewModel.load()

        #expect(viewModel.phase == .empty)
    }

    @Test
    func missingToolsAndOtherFailuresHaveTheirOwnStates() async {
        let missing = makeViewModel(SimulatorsServiceSpy(listFailure: .toolUnavailable))
        let failing = makeViewModel(SimulatorsServiceSpy(listFailure: .timedOut))

        await missing.load()
        await failing.load()

        #expect(missing.phase == .toolsUnavailable)
        #expect(failing.phase == .failed(.timedOut))
    }

    /// "Remover duplicados" pre-selects them and never deletes on its own.
    @Test
    func selectingTheDuplicatesNeverDeletes() async {
        let service = SimulatorsServiceSpy(devices: [recent, older, other])
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.selectDuplicates()

        #expect(viewModel.selectedUDIDs == ["B"])
        #expect(service.deletedDevices.isEmpty)
        #expect(viewModel.confirmation == nil)
    }

    @Test
    func deletingAsksFirstThenDeletesTheExactDevicesAndReloads() async {
        let service = SimulatorsServiceSpy(devices: [recent, older, other])
        let deletions = DeletionCounter()
        let viewModel = makeViewModel(service, onDeleted: deletions.record)
        await viewModel.load()

        viewModel.toggle("C")
        viewModel.toggle("A")
        viewModel.requestDeleteSelected()

        #expect(viewModel.confirmation == .devices([recent, other]))
        #expect(service.deletedDevices.isEmpty)

        await viewModel.confirm()

        #expect(service.deletedDevices.map { $0.map(\.udid) } == [["A", "C"]])
        #expect(viewModel.devices.map(\.udid) == ["B"])
        #expect(viewModel.selectedUDIDs.isEmpty)
        #expect(viewModel.confirmation == nil)
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.lastFailure == nil)
        #expect(deletions.count == 1)
        #expect(analytics.events.last?.name == "simulator_deleted")
        #expect(analytics.events.last?.properties["count"] as? Int == 2)
        #expect(analytics.events.last?.properties["reason"] as? String == "manual")
    }

    @Test
    func deletingOnlyTheSuggestedDuplicatesIsLoggedAsDuplicates() async {
        let viewModel = makeViewModel(SimulatorsServiceSpy(devices: [recent, older]))
        await viewModel.load()

        viewModel.selectDuplicates()
        viewModel.requestDeleteSelected()
        await viewModel.confirm()

        #expect(analytics.events.last?.properties["reason"] as? String == "duplicate")
    }

    @Test
    func cancellingTheConfirmationDeletesNothing() async {
        let service = SimulatorsServiceSpy(devices: [recent, older])
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.toggle("A")
        viewModel.requestDeleteSelected()
        viewModel.cancelConfirmation()
        await viewModel.confirm()

        #expect(service.deletedDevices.isEmpty)
        #expect(viewModel.selectedUDIDs == ["A"])
    }

    @Test
    func withNothingSelectedThereIsNothingToConfirm() async {
        let viewModel = makeViewModel(SimulatorsServiceSpy(devices: [recent]))
        await viewModel.load()

        viewModel.requestDeleteSelected()

        #expect(viewModel.confirmation == nil)
    }

    /// Deleting a runtime removes its simulators too, so it always asks (R9).
    @Test
    func aDeletableRuntimeIsDeletedAfterAConfirmation() async {
        let service = SimulatorsServiceSpy(devices: [recent, older, other], runtimes: runtimes)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.requestDeleteRuntime(runtimes[0])

        #expect(viewModel.confirmation == nil, "Runtimes bundled with Xcode cannot be deleted.")

        viewModel.requestDeleteRuntime(runtimes[1])

        #expect(viewModel.confirmation == .runtime(runtimes[1], dependentCount: 1))

        await viewModel.confirm()

        // Its simulators go first, by exact UDID, then the runtime itself.
        #expect(service.calls == ["delete C", "runtime delete R1"])
        #expect(service.deletedRuntimes == ["R1"])
        #expect(viewModel.runtimes.map(\.identifier) == ["R2"])
        #expect(viewModel.devices.map(\.udid) == ["A", "B"])
        #expect(analytics.events.last?.name == "runtime_deleted")
        #expect(analytics.events.last?.properties["count"] as? Int == 1)
    }

    @Test
    func aFailedDeletionIsShownAndNotLogged() async {
        let service = SimulatorsServiceSpy(devices: [recent], deleteFailure: .commandFailed(exitCode: 1, summary: "x"))
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.toggle("A")
        viewModel.requestDeleteSelected()
        await viewModel.confirm()

        #expect(viewModel.lastFailure == .commandFailed(exitCode: 1, summary: "x"))
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.devices.map(\.udid) == ["A"])
        #expect(analytics.events.isEmpty)
    }

    @Test
    func theSelectionOnlyKeepsDevicesThatStillExist() async {
        let service = SimulatorsServiceSpy(devices: [recent, older], runtimes: runtimes)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.toggle("A")
        viewModel.toggle("B")
        viewModel.toggle("B")
        viewModel.requestDeleteRuntime(runtimes[1])
        await viewModel.confirm()

        #expect(viewModel.selectedUDIDs == ["A"])
        #expect(viewModel.selectedBytes == recent.sizeBytes)
    }

    /// When its simulators cannot be deleted, the runtime is kept.
    @Test
    func aFailedSimulatorDeletionKeepsTheRuntime() async {
        let service = SimulatorsServiceSpy(devices: [other], runtimes: runtimes, deleteFailure: .inUse)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.requestDeleteRuntime(runtimes[1])
        await viewModel.confirm()

        #expect(service.calls == ["delete C"])
        #expect(service.deletedRuntimes.isEmpty)
        #expect(viewModel.lastFailure == .inUse)
        #expect(analytics.events.isEmpty)
    }

    @Test
    func aFailedRuntimeDeletionIsShownAndNotLogged() async {
        let service = SimulatorsServiceSpy(devices: [other], runtimes: runtimes, runtimeDeleteFailure: .timedOut)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.requestDeleteRuntime(runtimes[1])
        await viewModel.confirm()

        #expect(service.calls == ["delete C", "runtime delete R1"])
        #expect(viewModel.lastFailure == .timedOut)
        #expect(viewModel.runtimes.map(\.identifier) == ["R2", "R1"])
        #expect(!analytics.events.contains { $0.name == "runtime_deleted" })
    }

    /// Another image of the same runtime still serves the simulators, so they stay.
    @Test
    func theSimulatorsStayWhenAnotherImageServesTheirRuntime() async {
        let twin = runtime("R3", iOS271, deletable: true)
        let service = SimulatorsServiceSpy(devices: [other], runtimes: runtimes + [twin])
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.requestDeleteRuntime(runtimes[1])

        #expect(viewModel.confirmation == .runtime(runtimes[1], dependentCount: 0))

        await viewModel.confirm()

        #expect(service.calls == ["runtime delete R1"])
        #expect(viewModel.devices.map(\.udid) == ["C"])
    }

    /// A simulator booted after the list loaded is still shut down before it is deleted.
    @Test
    func deletingUsesTheCurrentStateOfEachSimulator() async {
        let service = SimulatorsServiceSpy(devices: [recent, older])
        let viewModel = makeViewModel(service)
        await viewModel.load()

        service.boot("A")
        viewModel.toggle("A")
        viewModel.requestDeleteSelected()
        await viewModel.confirm()

        #expect(service.deletedDevices.first?.map(\.state) == [.booted])
    }

    @Test(.timeLimit(.minutes(1)))
    func nothingElseHappensWhileDeleting() async {
        let service = SimulatorsServiceSpy(devices: [recent, older, other], holdsDeletions: true)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.toggle("A")
        viewModel.toggle("C")
        viewModel.requestDeleteSelected()

        var started = service.deletionStarted.stream.makeAsyncIterator()

        let deleting = Task { await viewModel.confirm() }
        _ = await started.next()

        #expect(viewModel.phase == .deleting(["A", "C"]))

        viewModel.toggle("B")
        viewModel.selectDuplicates()
        viewModel.requestDeleteSelected()
        await viewModel.load()

        #expect(viewModel.selectedUDIDs == ["A", "C"])
        #expect(viewModel.confirmation == nil)
        #expect(viewModel.phase == .deleting(["A", "C"]))

        service.releaseDeletions()
        await deleting.value

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.devices.map(\.udid) == ["B"])
    }

    @Test(.timeLimit(.minutes(1)))
    func aRuntimeBeingDeletedIsShownAsDeleting() async {
        let service = SimulatorsServiceSpy(runtimes: runtimes, holdsDeletions: true)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        viewModel.requestDeleteRuntime(runtimes[1])

        var started = service.deletionStarted.stream.makeAsyncIterator()

        let deleting = Task { await viewModel.confirm() }
        _ = await started.next()

        #expect(viewModel.phase == .deleting(["R1"]))

        service.releaseDeletions()
        await deleting.value
    }

    /// A Refresh whose listing ends while a deletion runs must not end the deletion's state, nor
    /// bring back what it deletes.
    @Test(.timeLimit(.minutes(1)))
    func aRefreshThatEndsDuringADeletionIsDiscarded() async {
        let service = SimulatorsServiceSpy(devices: [recent, older, other], holdsDeletions: true)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        service.holdNextListing()

        var listings = service.listingHeld.stream.makeAsyncIterator()

        let refreshing = Task { await viewModel.reloadIfOpened() }
        _ = await listings.next()

        viewModel.toggle("A")
        viewModel.requestDeleteSelected()

        var started = service.deletionStarted.stream.makeAsyncIterator()

        let deleting = Task { await viewModel.confirm() }
        _ = await started.next()

        service.releaseListing()
        await refreshing.value

        #expect(viewModel.phase == .deleting(["A"]))

        service.releaseDeletions()
        await deleting.value

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.devices.map(\.udid) == ["B", "C"])
    }

    @Test
    func loadingAgainRecoversFromAFailure() async {
        let service = SimulatorsServiceSpy(devices: [recent], listFailure: .toolUnavailable)
        let viewModel = makeViewModel(service)
        await viewModel.load()

        #expect(viewModel.phase == .toolsUnavailable)

        service.setListFailure(nil)
        await viewModel.load()

        #expect(viewModel.phase == .loaded)
    }

    /// The toolbar's Refresh reloads the section only once it was opened.
    @Test
    func refreshingOnlyReloadsASectionThatWasOpened() async {
        let service = SimulatorsServiceSpy(devices: [recent])
        let viewModel = makeViewModel(service)

        await viewModel.reloadIfOpened()

        #expect(viewModel.phase == .idle)

        await viewModel.load()
        service.boot("A")
        await viewModel.reloadIfOpened()

        #expect(viewModel.devices.first?.state == .booted)
    }

    // MARK: - Private Methods

    private func makeViewModel(
        _ service: SimulatorsServiceSpy,
        onDeleted: @escaping () async -> Void = {}
    ) -> SimulatorsViewModel {
        SimulatorsViewModel(
            simulators: service,
            downloader: RuntimeDownloaderSpy(),
            analytics: analytics,
            onDeleted: onDeleted
        )
    }

    private func device(_ udid: String, type: String, runtime: String, daysAgo: Double) -> SimulatorDevice {
        SimulatorDevice(
            udid: udid,
            name: type,
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.\(type)",
            runtimeIdentifier: runtime,
            state: .shutdown,
            isAvailable: true,
            lastUsedAt: Date(timeIntervalSince1970: 1_793_000_000 - daysAgo * 86_400),
            sizeBytes: 1_000
        )
    }

    private func runtime(_ identifier: String, _ runtimeIdentifier: String, deletable: Bool) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: identifier,
            runtimeIdentifier: runtimeIdentifier,
            version: "27",
            build: "24A1",
            platformIdentifier: "com.apple.platform.iphonesimulator",
            sizeBytes: 7_000,
            lastUsedAt: nil,
            isDeletable: deletable,
            state: "Ready",
            kind: deletable ? "Patchable Cryptex Disk Image" : "Bundled with Xcode"
        )
    }

}

@MainActor
private final class DeletionCounter {

    // MARK: - Public Properties

    private(set) var count = 0

    // MARK: - Public Methods

    func record() {
        count += 1
    }

}
