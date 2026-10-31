//
//  AppContainer.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

struct AppServices {

    // MARK: - Public Properties

    let commandExecutor: any CommandExecutor
    let analytics: any Analytics
    let errorReporter: any ErrorReporting
    let userDefaults: UserDefaults
    let preferences: Preferences
    let configuration: AppConfiguration

}

enum AppContainer {

    // MARK: - Public Properties

    static let testHostSuiteName = "didisouzacosta.CleanerXcode.test-host"

    // MARK: - Public Methods

    static func makeServices(
        environment: AppEnvironment,
        configuration: AppConfiguration,
        userDefaults: UserDefaults = .standard,
        makeHimetrica: @MainActor (_ apiKey: String, _ isEnabled: @escaping () -> Bool)
            -> any Analytics = HimetricaAnalytics.live,
        makeErrorReporter: @MainActor (ErrorReportingConfiguration)
            -> any ErrorReporting = SentryErrorReporter.init(configuration:)
    ) -> AppServices {
        // Tests and previews never touch the system nor start a third-party SDK.
        if environment.isRunningTests || environment.isRunningPreviews {
            guard let testHostDefaults = UserDefaults(suiteName: testHostSuiteName) else {
                preconditionFailure("Could not create the test host UserDefaults suite.")
            }

            return AppServices(
                commandExecutor: InertCommandExecutor(),
                analytics: NullAnalytics(),
                errorReporter: NullErrorReporter(),
                userDefaults: testHostDefaults,
                preferences: Preferences(testHostDefaults),
                configuration: configuration
            )
        }

        let errorReporter = errorReporter(
            environment: environment,
            configuration: configuration,
            factory: makeErrorReporter
        )
        errorReporter.start()

        let preferences = Preferences(userDefaults)
        // Read on every event, so the Settings switch applies at once.
        let store = UserDefaultsPreferencesStore(defaults: userDefaults)
        let analytics: any Analytics = if !environment.isDebug, let apiKey = configuration.himetricaAPIKey {
            makeHimetrica(apiKey) { store.bool(for: SettingsViewModel.usageStatisticsKey) ?? true }
        } else {
            NullAnalytics()
        }

        return AppServices(
            commandExecutor: Shell(),
            analytics: analytics,
            errorReporter: errorReporter,
            userDefaults: userDefaults,
            preferences: preferences,
            configuration: configuration
        )
    }

    /// The main window's state. The test host and previews get inert services over folders that
    /// do not exist, so the window opens and measures without reading this Mac or running `simctl`.
    static func makeCleanerViewModel(
        environment: AppEnvironment,
        services: AppServices,
        loginItem: any LoginItemManaging = MainAppLoginItem()
    ) -> CleanerViewModel {
        let store = UserDefaultsPreferencesStore(defaults: services.userDefaults)
        let appBundleIdentifier = services.configuration.bundleIdentifier ?? ""

        if environment.isRunningTests || environment.isRunningPreviews {
            return CleanerViewModel(
                catalog: CleanupCatalog(locations: .inert),
                measurer: CategorySizeMeasurer(scanner: InertDiskUsageScanner()),
                simulators: InertSimulatorManager(),
                executor: InertCleanupExecutor(),
                preferences: store,
                runningApplications: InertRunningApplications(),
                analytics: services.analytics,
                errorReporter: services.errorReporter,
                appBundleIdentifier: appBundleIdentifier,
                minimumTemporaryAgeInDays: SettingsViewModel.storedMinimumAge(in: store)
            )
        }

        let locations = CleanupLocations.current()
        let catalog = CleanupCatalog(locations: locations)

        // Before the view model reads the selection; the outcome goes to Sentry without the keys.
        let outcome = PreferencesMigrator(categories: catalog.categories).migrate(store, loginItem: loginItem)

        if outcome.restoredCorruptedValueCount > 0 {
            services.errorReporter.breadcrumb(.preferencesRestored)
        }

        if outcome.loginItemFailure != nil {
            services.errorReporter.breadcrumb(.loginItemMigrationFailed)
        }

        let scanner = FileSystemSizeScanner()
        let simulators = SimctlSimulatorService(scanner: scanner)
        let runningApplications = WorkspaceRunningApplications()
        let executor = CleanupExecutor(
            locations: locations,
            remover: FileSystemRemover(policy: catalog.makeSafePathPolicy(), locations: locations),
            simulators: simulators,
            scanner: scanner,
            runningApplications: runningApplications,
            appBundleIdentifier: appBundleIdentifier
        )

        return CleanerViewModel(
            catalog: catalog,
            measurer: CategorySizeMeasurer(scanner: scanner),
            simulators: simulators,
            executor: executor,
            preferences: store,
            runningApplications: runningApplications,
            analytics: services.analytics,
            errorReporter: services.errorReporter,
            appBundleIdentifier: appBundleIdentifier,
            minimumTemporaryAgeInDays: SettingsViewModel.storedMinimumAge(in: store)
        )
    }

    /// Settings. The test host and previews never register a login item.
    static func makeSettingsViewModel(
        environment: AppEnvironment,
        services: AppServices,
        onMinimumAgeChanged: @escaping (Int) -> Void = { _ in }
    ) -> SettingsViewModel {
        let loginItem: any LoginItemManaging = environment.isRunningTests || environment.isRunningPreviews
            ? InertLoginItem()
            : MainAppLoginItem()

        return SettingsViewModel(
            store: UserDefaultsPreferencesStore(defaults: services.userDefaults),
            loginItem: loginItem,
            analytics: services.analytics,
            onMinimumAgeChanged: onMinimumAgeChanged
        )
    }

    /// The Simulators section. The test host and previews never run `simctl`.
    static func makeSimulatorsViewModel(
        environment: AppEnvironment,
        services: AppServices,
        onDeleted: @escaping () async -> Void = {}
    ) -> SimulatorsViewModel {
        let simulators: any SimulatorManaging = environment.isRunningTests || environment.isRunningPreviews
            ? InertSimulatorManager()
            : SimctlSimulatorService()

        return SimulatorsViewModel(simulators: simulators, analytics: services.analytics, onDeleted: onDeleted)
    }

    // MARK: - Private Methods

    /// Sentry runs in Debug and Release, in separate environments, whenever a DSN is configured.
    private static func errorReporter(
        environment: AppEnvironment,
        configuration: AppConfiguration,
        factory: @MainActor (ErrorReportingConfiguration) -> any ErrorReporting
    ) -> any ErrorReporting {
        guard let dsn = configuration.sentryDSN else { return NullErrorReporter() }

        return factory(
            ErrorReportingConfiguration(
                dsn: dsn,
                bundleIdentifier: configuration.bundleIdentifier,
                version: configuration.version,
                build: configuration.build,
                isDebug: environment.isDebug
            )
        )
    }

}
