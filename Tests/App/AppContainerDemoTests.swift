//
//  AppContainerDemoTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The demo (C36) gets mocked services only: no disk, `simctl`, `xcodebuild`, network, login item,
/// Sentry nor Himetrica.
struct AppContainerDemoTests {

    // MARK: - Private Properties

    private let environment = AppEnvironment(isRunningTests: false, isDebug: true, isDemo: true)

    // MARK: - Public Methods

    @Test
    func demoNeverStartsTheSDKs() {
        let configuration = AppConfiguration(
            himetricaAPIKey: "hm_pk_test",
            sentryDSN: "https://key@o1.ingest.sentry.io/2"
        )

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: configuration,
            makeHimetrica: { _, _ in preconditionFailure("The demo must not start Himetrica.") },
            makeErrorReporter: { _ in preconditionFailure("The demo must not start Sentry.") }
        )

        #expect(services.analytics is NullAnalytics)
        #expect(services.errorReporter is NullErrorReporter)
    }

    @Test
    func demoKeepsItsPreferencesApart() {
        let services = AppContainer.makeServices(environment: environment, configuration: AppConfiguration())

        #expect(services.userDefaults !== UserDefaults.standard)
        #expect(services.userDefaults.dictionaryRepresentation()[SettingsViewModel.minimumAgeKey] == nil)
    }

    @Test
    func demoStartsWithFreshPreferences() throws {
        let suite = try #require(UserDefaults(suiteName: AppContainer.demoSuiteName))

        suite.set(true, forKey: "left-by-an-earlier-demo")

        let services = AppContainer.makeServices(environment: environment, configuration: AppConfiguration())

        #expect(services.userDefaults.object(forKey: "left-by-an-earlier-demo") == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func demoWindowMeasuresTheMockedSizes() async {
        let loginItem = LoginItemSpy(status: .notRegistered)
        let services = AppContainer.makeServices(environment: environment, configuration: AppConfiguration())
        let viewModel = AppContainer.makeCleanerViewModel(
            environment: environment,
            services: services,
            loginItem: loginItem,
            legacyPreferences: { preconditionFailure("The demo must not migrate preferences.") }
        )

        await viewModel.refresh()

        #expect(viewModel.totalBytes == 40_400_000_000)
        #expect(viewModel.totalBytes == selectedByDefaultBytes())
        #expect(loginItem.requests.isEmpty)
    }

    @Test
    func demoWindowOnlyKnowsTheInertFolders() {
        let services = AppContainer.makeServices(environment: environment, configuration: AppConfiguration())
        let viewModel = AppContainer.makeCleanerViewModel(environment: environment, services: services)
        let roots = viewModel.categories.flatMap(\.targets).map { $0.root.path(percentEncoded: false) }

        #expect(roots.isEmpty == false)
        #expect(roots.allSatisfy { $0.hasPrefix(CleanupLocations.inertBasePath) })
    }

    @Test
    func demoGetsSettingsThatNeverTouchTheLoginItem() {
        let services = AppContainer.makeServices(environment: environment, configuration: AppConfiguration())

        let viewModel = AppContainer.makeSettingsViewModel(environment: environment, services: services)

        #expect(viewModel.loginItem is InertLoginItem)
    }

    @Test
    func demoNeverChecksForUpdatesOverTheNetwork() {
        let configuration = AppConfiguration(versionFileURL: URL(string: "https://updates.invalid/version.json"))
        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        let viewModel = AppContainer.makeUpdateViewModel(environment: environment, services: services)

        #expect(viewModel.checker is InertVersionChecker)
    }

    @Test
    func demoSimulatorsComeFromTheFixtures() async {
        let services = AppContainer.makeServices(environment: environment, configuration: AppConfiguration())
        let viewModel = AppContainer.makeSimulatorsViewModel(environment: environment, services: services)

        #expect((viewModel.simulators is SimctlSimulatorService) == false)
        #expect((viewModel.simulators is InertSimulatorManager) == false)
        #expect(viewModel.downloader is PreviewRuntimeDownloader)

        await viewModel.load()

        #expect(viewModel.devices.isEmpty == false)
    }

    @Test
    func demoHasNoBackgroundMeasurement() {
        let scheduler = AppContainer.makeBackgroundMeasurementScheduler(
            environment: environment,
            measuring: AppContainer.makeCleanerViewModel(
                environment: environment,
                services: AppContainer.makeServices(environment: environment, configuration: AppConfiguration())
            ),
            isEnabled: { true },
            isBusy: { false }
        )

        #expect(scheduler == nil)
    }

    // MARK: - Private Methods

    /// What the window offers to clean on a fresh start: the categories on by default.
    private func selectedByDefaultBytes() -> Int64 {
        let state = DemoDiskState()

        return CleanupCatalog(locations: .inert).categories
            .filter(\.isEnabledByDefault)
            .flatMap(\.targets)
            .reduce(0) { $0 + state.size(of: $1) }
    }

}
