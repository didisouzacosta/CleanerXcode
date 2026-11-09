//
//  UpdateViewModelTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The update button of the footer and the About page (R16, R17, C42): it shows what the updater
/// found, errors stay silent and become a breadcrumb, and opening it logs `update_opened`.
struct UpdateViewModelTests {

    // MARK: - Private Properties

    private let analytics = AnalyticsStub()
    private let errorReporter = ErrorReporterStub()

    // MARK: - Public Methods

    @Test
    func aNewerVersionIsOffered() async {
        let updater = SoftwareUpdaterFake(result: .success("1.0.1"))
        let viewModel = makeViewModel(updater)

        #expect(viewModel.availableVersion == nil)

        await viewModel.check()

        #expect(viewModel.availableVersion == "1.0.1")
    }

    @Test
    func nothingIsOfferedWhenTheAppIsUpToDate() async {
        let viewModel = makeViewModel(SoftwareUpdaterFake(result: .success(nil)))

        await viewModel.check()

        #expect(viewModel.availableVersion == nil)
    }

    @Test
    func errorsStaySilentAndLeaveABreadcrumb() async {
        let viewModel = makeViewModel(SoftwareUpdaterFake(result: .failure(URLError(.notConnectedToInternet))))

        await viewModel.check()

        #expect(viewModel.availableVersion == nil)
        #expect(errorReporter.stages == [.updateCheckFailed])
        #expect(analytics.events.isEmpty)
    }

    /// Closing the window cancels the check: that is not a failure.
    @Test
    func aCancelledCheckLeavesNoBreadcrumb() async {
        let cancelled = makeViewModel(SoftwareUpdaterFake(result: .failure(CancellationError())))
        let urlCancelled = makeViewModel(SoftwareUpdaterFake(result: .failure(URLError(.cancelled))))

        await cancelled.check()
        await urlCancelled.check()

        #expect(errorReporter.stages.isEmpty)
    }

    /// Sparkle answers a check that overlaps a running one with a cancellation: the version it
    /// already found stays on screen.
    @Test
    func aCancelledCheckKeepsTheVersionFound() async {
        let updater = SoftwareUpdaterFake(result: .success("1.0.1"))
        let viewModel = makeViewModel(updater)

        await viewModel.check()
        updater.result = .failure(CancellationError())
        await viewModel.check()

        #expect(viewModel.availableVersion == "1.0.1")
    }

    /// The automatic checks can change in Sparkle's own window; each check reads them again.
    @Test
    func eachCheckReadsTheAutomaticChecksAgain() async {
        let updater = SoftwareUpdaterFake(result: .success(nil), supportsUserChecks: true)
        let viewModel = makeViewModel(updater)

        updater.setAutomaticallyChecksForUpdates(false)
        await viewModel.check()

        #expect(viewModel.automaticallyChecksForUpdates == false)
    }

    @Test
    func openingTheUpdatePresentsItAndIsLogged() async {
        let updater = SoftwareUpdaterFake(result: .success("1.0.1"))
        let viewModel = makeViewModel(updater)

        await viewModel.check()
        viewModel.openUpdate()

        #expect(updater.presentedUpdates == 1)
        #expect(analytics.events.map(\.name) == ["update_opened"])
    }

    @Test
    func checkingFromTheMenuGoesToTheUpdater() {
        let updater = SoftwareUpdaterFake(result: .success(nil), supportsUserChecks: true)
        let viewModel = makeViewModel(updater)

        viewModel.checkForUpdates()

        #expect(viewModel.canCheckForUpdates)
        #expect(updater.userChecks == 1)
    }

    @Test
    func theMenuCheckIsUnavailableWithoutSparkle() {
        let updater = SoftwareUpdaterFake(result: .success(nil), supportsUserChecks: false)
        let viewModel = makeViewModel(updater)

        viewModel.checkForUpdates()

        #expect(viewModel.canCheckForUpdates == false)
        #expect(updater.userChecks == 0)
    }

    @Test
    func automaticChecksFollowTheSwitch() {
        let updater = SoftwareUpdaterFake(result: .success(nil), supportsUserChecks: true)
        let viewModel = makeViewModel(updater)

        #expect(viewModel.automaticallyChecksForUpdates)

        viewModel.setAutomaticallyChecksForUpdates(false)

        #expect(viewModel.automaticallyChecksForUpdates == false)
        #expect(updater.automaticallyChecksForUpdates == false)
    }

    // MARK: - Private Methods

    private func makeViewModel(_ updater: SoftwareUpdaterFake) -> UpdateViewModel {
        UpdateViewModel(updater: updater, analytics: analytics, errorReporter: errorReporter)
    }

}

private final class SoftwareUpdaterFake: SoftwareUpdating {

    // MARK: - Public Properties

    let supportsUserChecks: Bool

    private(set) var automaticallyChecksForUpdates = true

    private(set) var presentedUpdates = 0
    private(set) var userChecks = 0

    var result: Result<String?, any Error>

    // MARK: - Initializers

    init(result: Result<String?, any Error>, supportsUserChecks: Bool = false) {
        self.result = result
        self.supportsUserChecks = supportsUserChecks
    }

    // MARK: - Public Methods

    func newerVersion() throws -> String? {
        try result.get()
    }

    func presentUpdate() {
        presentedUpdates += 1
    }

    func checkForUpdates() {
        userChecks += 1
    }

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
        automaticallyChecksForUpdates = isOn
    }

}
