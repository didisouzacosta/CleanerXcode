//
//  UpdateViewModelTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// "Atualizar" in the footer and the About tab (R16, R17): only a newer version shows it, network
/// errors stay silent and become a breadcrumb, and opening it logs `update_opened`.
struct UpdateViewModelTests {

    // MARK: - Private Properties

    private let analytics = AnalyticsStub()
    private let errorReporter = ErrorReporterStub()

    // MARK: - Public Methods

    @Test
    func aNewerVersionIsOffered() async {
        let viewModel = makeViewModel(current: "0.9.0", build: "90", remote: .success(version("0.10.0", "100")))

        #expect(viewModel.availableUpdate == nil)

        await viewModel.check()

        #expect(viewModel.availableUpdate?.version == "0.10.0")
    }

    @Test
    func theSameOrAnOlderVersionIsNot() async {
        let same = makeViewModel(current: "1.0.0", build: "115", remote: .success(version("1.0.0", "115")))
        let older = makeViewModel(current: "1.0.0", build: "115", remote: .success(version("0.7.0", "70")))

        await same.check()
        await older.check()

        #expect(same.availableUpdate == nil)
        #expect(older.availableUpdate == nil)
    }

    @Test
    func aNewerBuildOfTheSameVersionIsOffered() async {
        let viewModel = makeViewModel(current: "1.0.0", build: "115", remote: .success(version("1.0.0", "116")))

        await viewModel.check()

        #expect(viewModel.availableUpdate?.build == "116")
    }

    @Test
    func networkErrorsStaySilentAndLeaveABreadcrumb() async {
        let viewModel = makeViewModel(current: "1.0.0", build: "1", remote: .failure(URLError(.notConnectedToInternet)))

        await viewModel.check()

        #expect(viewModel.availableUpdate == nil)
        #expect(errorReporter.stages == [.updateCheckFailed])
        #expect(analytics.events.isEmpty)
    }

    /// Closing the window cancels the check: that is not a failure.
    @Test
    func aCancelledCheckLeavesNoBreadcrumb() async {
        let cancelled = makeViewModel(current: "1.0.0", build: "1", remote: .failure(CancellationError()))
        let urlCancelled = makeViewModel(current: "1.0.0", build: "1", remote: .failure(URLError(.cancelled)))

        await cancelled.check()
        await urlCancelled.check()

        #expect(errorReporter.stages.isEmpty)
    }

    @Test
    func anUnreadableRemoteVersionIsIgnored() async {
        let viewModel = makeViewModel(current: "1.0.0", build: "1", remote: .success(version("next", "1")))

        await viewModel.check()

        #expect(viewModel.availableUpdate == nil)
    }

    @Test
    func openingTheUpdateIsLogged() async {
        let viewModel = makeViewModel(current: "0.9.0", build: "1", remote: .success(version("1.0.0", "1")))
        await viewModel.check()

        viewModel.logUpdateOpened()

        #expect(analytics.events.map(\.name) == ["update_opened"])
    }

    // MARK: - Private Methods

    private func makeViewModel(current: String, build: String, remote: Result<Version, any Error>) -> UpdateViewModel {
        UpdateViewModel(
            currentVersion: current,
            currentBuild: build,
            checker: VersionCheckerStub(result: remote),
            analytics: analytics,
            errorReporter: errorReporter
        )
    }

    private func version(_ version: String, _ build: String) -> Version {
        Version(version: version, build: build, downloadURL: URL(filePath: "/app.dmg"))
    }

}

private struct VersionCheckerStub: VersionChecking {

    // MARK: - Public Properties

    let result: Result<Version, any Error>

    // MARK: - Public Methods

    func latestVersion() throws -> Version {
        try result.get()
    }

}
