//
//  SimulatorsViewModelLoadingTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// `loadOnActivation` and `loadIfNeeded` (D9): the overview card and the sidebar badge need the
/// lists, so the window lists them on its first activation; the page lists again when nothing is
/// shown, never twice at once and never during a deletion.
struct SimulatorsViewModelLoadingTests {

    // MARK: - Private Properties

    private let iOS272 = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
    private let iOS271 = "com.apple.CoreSimulator.SimRuntime.iOS-27-1"

    private var recent: SimulatorDevice {
        device("A", type: "iPhone-17-Pro", runtime: iOS272, daysAgo: 2)
    }

    private var older: SimulatorDevice {
        device("B", type: "iPhone-17-Pro", runtime: iOS272, daysAgo: 38)
    }

    private var other: SimulatorDevice {
        device("C", type: "iPad-Pro-13", runtime: iOS271, daysAgo: 12)
    }

    // MARK: - Public Methods

    /// Only when nothing is listed, listing or being deleted.
    @Test
    func loadingIfNeededListsOnlyWhenTheListsAreMissing() async {
        let fresh = SimulatorsServiceSpy(devices: [recent])
        let idle = makeViewModel(fresh)

        await idle.loadIfNeeded()

        #expect(idle.phase == .loaded)
        #expect(fresh.listingCount == 1)

        await idle.loadIfNeeded()

        #expect(fresh.listingCount == 1, "Loaded lists are kept; Refresh lists them again.")

        let emptyService = SimulatorsServiceSpy()
        let empty = makeViewModel(emptyService)

        await empty.load()
        await empty.loadIfNeeded()

        #expect(empty.phase == .empty)
        #expect(emptyService.listingCount == 2)
    }

    @Test
    func loadingIfNeededRecoversFromAFailureOrMissingTools() async {
        for failure: CleanupError in [.timedOut, .toolUnavailable] {
            let service = SimulatorsServiceSpy(devices: [recent], listFailure: failure)
            let viewModel = makeViewModel(service)

            await viewModel.load()

            #expect(viewModel.phase != .loaded, "\(failure)")

            service.setListFailure(nil)
            await viewModel.loadIfNeeded()

            #expect(viewModel.phase == .loaded, "\(failure)")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func loadingIfNeededWaitsForAListingInProgress() async {
        let service = SimulatorsServiceSpy(devices: [recent])
        let viewModel = makeViewModel(service)

        service.holdNextListing()

        var listings = service.listingHeld.stream.makeAsyncIterator()

        let loading = Task { await viewModel.load() }
        _ = await listings.next()

        #expect(viewModel.phase == .loading)

        await viewModel.loadIfNeeded()
        service.releaseListing()
        await loading.value

        #expect(service.listingCount == 1)
        #expect(viewModel.phase == .loaded)
    }

    @Test(.timeLimit(.minutes(1)))
    func loadingIfNeededNeverListsDuringADeletion() async {
        let service = SimulatorsServiceSpy(devices: [recent, older, other], holdsDeletions: true)
        let viewModel = makeViewModel(service)

        await viewModel.load()
        viewModel.toggle("B")
        viewModel.requestDeleteSelected()

        var started = service.deletionStarted.stream.makeAsyncIterator()

        let deleting = Task { await viewModel.confirm() }
        _ = await started.next()

        let listings = service.listingCount

        await viewModel.loadIfNeeded()

        #expect(service.listingCount == listings)
        #expect(viewModel.phase == .deleting(["B"]))

        service.releaseDeletions()
        await deleting.value
    }

    /// The window lists on its first activation only: activating it again with no simulators,
    /// without the tools or after a failure never runs `simctl` again (review B2).
    @Test
    func activationListsOnlyTheFirstTime() async {
        let idleService = SimulatorsServiceSpy(devices: [recent])
        let idle = makeViewModel(idleService)

        await idle.loadOnActivation()

        #expect(idle.phase == .loaded)
        #expect(idleService.listingCount == 1)

        let cases: [(String, SimulatorsServiceSpy)] = [
            ("empty", SimulatorsServiceSpy()),
            ("failed", SimulatorsServiceSpy(devices: [recent], listFailure: .timedOut)),
            ("tools unavailable", SimulatorsServiceSpy(devices: [recent], listFailure: .toolUnavailable)),
        ]

        for (name, service) in cases {
            let viewModel = makeViewModel(service)

            await viewModel.loadOnActivation()
            await viewModel.loadOnActivation()

            #expect(service.listingCount == 1, "\(name)")
        }
    }

    /// Opening the page still lists again after an empty list, a failure or missing tools.
    @Test
    func thePageStillListsAfterAnActivationThatFoundNothing() async {
        let cases: [(String, SimulatorsServiceSpy)] = [
            ("empty", SimulatorsServiceSpy()),
            ("failed", SimulatorsServiceSpy(devices: [recent], listFailure: .timedOut)),
            ("tools unavailable", SimulatorsServiceSpy(devices: [recent], listFailure: .toolUnavailable)),
        ]

        for (name, service) in cases {
            let viewModel = makeViewModel(service)

            await viewModel.loadOnActivation()
            await viewModel.loadIfNeeded()

            #expect(service.listingCount == 2, "\(name)")
        }
    }

    // MARK: - Private Methods

    private func makeViewModel(_ service: SimulatorsServiceSpy) -> SimulatorsViewModel {
        SimulatorsViewModel(simulators: service, downloader: RuntimeDownloaderSpy(), analytics: AnalyticsStub())
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

}
