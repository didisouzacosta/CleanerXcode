//
//  AppContainerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct AppContainerTests {

    // MARK: - Private Properties

    private let configuration = AppConfiguration(versionFileURL: nil)
    private let dsn = "https://key@o1.ingest.sentry.io/2"

    // MARK: - Public Methods

    @Test
    func whenRunningTestsTheSDKsStayOff() {
        let environment = AppEnvironment(isRunningTests: true, isDebug: true)

        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        #expect(services.analytics is NullAnalytics)
        #expect(services.errorReporter is NullErrorReporter)
    }

    @Test
    func whenRunningTestsPreferencesDoNotUseStandardUserDefaults() {
        let environment = AppEnvironment(isRunningTests: true, isDebug: false)

        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        #expect(services.userDefaults !== UserDefaults.standard)
    }

    @Test
    func debugBuildRunsWithoutAnalytics() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: true)

        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        #expect(services.analytics is NullAnalytics)
        #expect(services.userDefaults === UserDefaults.standard)
    }

    @Test
    func releaseBuildWithoutAKeyRunsWithoutAnalytics() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: false)
        let factory = HimetricaFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: configuration,
            makeHimetrica: factory.make
        )

        #expect(services.analytics is NullAnalytics)
        #expect(factory.apiKeys.isEmpty)
    }

    @Test
    func releaseBuildWithAKeyUsesHimetrica() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: false)
        let factory = HimetricaFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(himetricaAPIKey: "hm_pk_test"),
            makeHimetrica: factory.make
        )

        #expect(services.analytics is SpyAnalytics)
        #expect(factory.apiKeys == ["hm_pk_test"])
    }

    @Test
    func himetricaFollowsTheAnonymousStatisticsPreference() {
        UserDefaults.test.reset()

        defer { UserDefaults.test.reset() }

        let environment = AppEnvironment(isRunningTests: false, isDebug: false)
        let factory = HimetricaFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(himetricaAPIKey: "hm_pk_test"),
            userDefaults: .test,
            makeHimetrica: factory.make
        )

        #expect(services.userDefaults === UserDefaults.test)

        // The Settings switch writes through the store; the adapter reads it on every event.
        let store = UserDefaultsPreferencesStore(defaults: .test)

        #expect(factory.isEnabled?() == true, "On by default.")

        store.set(false, for: SettingsViewModel.usageStatisticsKey)
        #expect(factory.isEnabled?() == false)

        store.set(true, for: SettingsViewModel.usageStatisticsKey)
        #expect(factory.isEnabled?() == true)
    }

    @Test
    func debugBuildNeverUsesHimetricaEvenWithAKey() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: true)
        let factory = HimetricaFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(himetricaAPIKey: "hm_pk_test"),
            makeHimetrica: factory.make
        )

        #expect(services.analytics is NullAnalytics)
        #expect(factory.apiKeys.isEmpty)
    }

    @Test
    func testsNeverUseHimetricaEvenWithAKey() {
        let environment = AppEnvironment(isRunningTests: true, isDebug: false)
        let factory = HimetricaFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(himetricaAPIKey: "hm_pk_test"),
            makeHimetrica: factory.make
        )

        #expect(services.analytics is NullAnalytics)
        #expect(factory.apiKeys.isEmpty)
    }

    @Test
    func testsNeverStartSentryEvenWithADSN() {
        let environment = AppEnvironment(isRunningTests: true, isDebug: true)
        let factory = ErrorReporterFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(sentryDSN: dsn),
            makeErrorReporter: factory.make
        )

        #expect(services.errorReporter is NullErrorReporter)
        #expect(factory.configurations.isEmpty)
    }

    @Test
    func previewsGetInertServicesWithoutSentry() {
        let environment = AppEnvironment(isRunningTests: false, isRunningPreviews: true, isDebug: true)
        let factory = ErrorReporterFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(sentryDSN: dsn),
            makeErrorReporter: factory.make
        )

        #expect(services.analytics is NullAnalytics)
        #expect(services.errorReporter is NullErrorReporter)
        #expect(factory.configurations.isEmpty)
    }

    @Test
    func withoutADSNSentryStaysOff() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: false)
        let factory = ErrorReporterFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: configuration,
            makeErrorReporter: factory.make
        )

        #expect(services.errorReporter is NullErrorReporter)
        #expect(factory.configurations.isEmpty)
    }

    @Test
    func debugBuildWithADSNStartsSentryInTheDebugEnvironment() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: true)
        let factory = ErrorReporterFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(
                sentryDSN: dsn,
                bundleIdentifier: "didisouzacosta.CleanerXcode",
                version: "1.0.0",
                build: "120"
            ),
            makeErrorReporter: factory.make
        )

        #expect((services.errorReporter as? ErrorReporterStub) === factory.reporter)
        #expect(factory.configurations.map(\.environment) == ["debug"])
        #expect(factory.configurations.first?.releaseName == "didisouzacosta.CleanerXcode@1.0.0+120")
        #expect(factory.reporter.startCount == 1)
    }

    @Test
    func releaseBuildWithADSNStartsSentryInTheProductionEnvironment() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: false)
        let factory = ErrorReporterFactorySpy()

        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(sentryDSN: dsn),
            makeErrorReporter: factory.make
        )

        #expect((services.errorReporter as? ErrorReporterStub) === factory.reporter)
        #expect(factory.configurations.map(\.environment) == ["production"])
        #expect(factory.reporter.startCount == 1)
    }

    @Test
    func testsGetACleanerThatNeverReadsTheDiskNorRunsSimctl() async {
        let environment = AppEnvironment(isRunningTests: true, isDebug: true)
        let services = AppContainer.makeServices(environment: environment, configuration: configuration)
        let loginItem = LoginItemSpy(status: .notRegistered)

        let viewModel = AppContainer.makeCleanerViewModel(
            environment: environment,
            services: services,
            loginItem: loginItem
        )
        await viewModel.refresh()

        // Every root sits under a folder that does not exist, so nothing on this Mac is read.
        let roots = viewModel.categories.flatMap(\.targets).map { $0.root.path(percentEncoded: false) }

        #expect(!FileManager.default.fileExists(atPath: CleanupLocations.inertBasePath))
        #expect(roots.allSatisfy { $0.hasPrefix(CleanupLocations.inertBasePath) })

        for category in viewModel.categories {
            let needsTools = category.operation.needsSimulatorTools || category.shutsDownSimulators
            let expected: CategoryRowState = needsTools ? .unavailable(.toolsUnavailable) : .empty

            #expect(viewModel.rows[category.id] == expected, "\(category.id)")
        }
        #expect(loginItem.requests.isEmpty)
    }

    @Test
    func testsGetASimulatorsSectionThatNeverRunsSimctl() async {
        let environment = AppEnvironment(isRunningTests: true, isDebug: true)
        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        let viewModel = AppContainer.makeSimulatorsViewModel(environment: environment, services: services)
        await viewModel.load()

        #expect(viewModel.phase == .toolsUnavailable)
    }

    @Test
    func outsideTestsTheSimulatorsSectionUsesSimctl() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: true)
        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        let viewModel = AppContainer.makeSimulatorsViewModel(environment: environment, services: services)

        #expect(viewModel.simulators is SimctlSimulatorService)
    }

    @Test
    func testsGetSettingsThatNeverTouchTheLoginItem() {
        let environment = AppEnvironment(isRunningTests: true, isDebug: true)
        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        let viewModel = AppContainer.makeSettingsViewModel(environment: environment, services: services)

        // Only the type is checked: a real login item must never be exercised by a test.
        #expect(viewModel.loginItem is InertLoginItem)
    }

    @Test
    func testsNeverCheckForUpdatesOverTheNetwork() {
        let environment = AppEnvironment(isRunningTests: true, isDebug: true)
        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(versionFileURL: URL(string: "https://updates.invalid/version.json"))
        )

        let viewModel = AppContainer.makeUpdateViewModel(environment: environment, services: services)

        #expect(viewModel.checker is InertVersionChecker)
    }

    /// Errors are silent by design, so a wrong branch would quietly disable updates.
    @Test
    func theAppChecksForUpdatesAndPreviewsDoNot() {
        let configuration = AppConfiguration(versionFileURL: URL(string: "https://updates.invalid/version.json"))
        let app = AppEnvironment(isRunningTests: false, isDebug: true)
        let previews = AppEnvironment(isRunningTests: false, isRunningPreviews: true, isDebug: true)

        let appViewModel = AppContainer.makeUpdateViewModel(
            environment: app,
            services: AppContainer.makeServices(environment: app, configuration: configuration)
        )
        let previewViewModel = AppContainer.makeUpdateViewModel(
            environment: previews,
            services: AppContainer.makeServices(environment: previews, configuration: configuration)
        )

        #expect(appViewModel.checker is RemoteVersionChecker)
        #expect(previewViewModel.checker is InertVersionChecker)
    }

    /// A restored value and a failed login item reach Sentry as breadcrumbs, without the key (§9).
    @Test
    func theMigrationOutcomeIsReportedWithoutTheKeys() {
        let defaults = TestPreferencesDomain.defaults(named: "container.outcome")

        defer { TestPreferencesDomain.remove(named: "container.outcome") }

        defaults.set("garbage", forKey: CleanupCategoryID.removeArchives.rawValue)
        UserDefaultsPreferencesStore(defaults: defaults).set(true, for: PreferencesMigrator.legacyLaunchAtLoginKey)

        let reporter = ErrorReporterStub()
        let services = AppServices(
            analytics: NullAnalytics(),
            errorReporter: reporter,
            userDefaults: defaults,
            configuration: configuration
        )

        _ = AppContainer.makeCleanerViewModel(
            environment: AppEnvironment(isRunningTests: false, isDebug: true),
            services: services,
            loginItem: LoginItemSpy(status: .notRegistered, failure: .permissionDenied)
        )

        #expect(reporter.stages == [.preferencesRestored, .loginItemMigrationFailed])
    }

    /// The saved choices are migrated to v2 when the window's state is made (section 9).
    @Test
    func outsideTestsTheCleanerMigratesThePreferences() {
        let defaults = TestPreferencesDomain.defaults(named: "container.migration")

        defer { TestPreferencesDomain.remove(named: "container.migration") }

        let environment = AppEnvironment(isRunningTests: false, isDebug: true)
        let services = AppContainer.makeServices(
            environment: environment,
            configuration: configuration,
            userDefaults: defaults
        )
        let loginItem = LoginItemSpy(status: .notRegistered)

        let viewModel = AppContainer.makeCleanerViewModel(
            environment: environment,
            services: services,
            loginItem: loginItem
        )

        #expect(UserDefaultsPreferencesStore(defaults: defaults).schemaVersion == PreferencesMigrator
            .currentSchemaVersion)
        #expect(viewModel.selectedIDs.contains(.removeDerivedData))
        #expect(!viewModel.selectedIDs.contains(.removeArchives))
    }

}

private final class SpyAnalytics: Analytics {

    func log(_ event: AnalyticsEvent) {}

}

private final class HimetricaFactorySpy {

    // MARK: - Public Properties

    private(set) var apiKeys: [String] = []
    private(set) var isEnabled: (() -> Bool)?

    // MARK: - Public Methods

    func make(apiKey: String, isEnabled: @escaping () -> Bool) -> any Analytics {
        apiKeys.append(apiKey)
        self.isEnabled = isEnabled
        return SpyAnalytics()
    }

}

private final class ErrorReporterFactorySpy {

    // MARK: - Public Properties

    let reporter = ErrorReporterStub()

    private(set) var configurations: [ErrorReportingConfiguration] = []

    // MARK: - Public Methods

    func make(configuration: ErrorReportingConfiguration) -> any ErrorReporting {
        configurations.append(configuration)
        return reporter
    }

}
