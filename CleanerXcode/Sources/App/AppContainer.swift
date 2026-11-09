//
//  AppContainer.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

struct AppServices {

    // MARK: - Public Properties

    let analytics: any Analytics
    let errorReporter: any ErrorReporting
    let userDefaults: UserDefaults
    let configuration: AppConfiguration

}

enum AppContainer {

    // MARK: - Public Properties

    static let testHostSuiteName = "didisouzacosta.CleanerXcode.test-host"
    /// The app's bundle id, when the build does not say.
    static let defaultBundleIdentifier = "com.didisouzacosta.CleanerXcode"
    /// The user's choices copied from the 0.7 bundle id (C33, D3). "Launch at login" has its own
    /// rule inside `PreferencesDomainMigrator`; window state and the schema version stay behind.
    static let legacyDomainKeys: [String] = CleanupCategoryID.allCases.map(\.rawValue) + [
        PreferencesMigrator.showSizeInMenuBarKey,
        PreferencesMigrator.showMenuBarExtraKey,
        SettingsViewModel.minimumAgeKey,
        SettingsViewModel.usageStatisticsKey,
        HimetricaAnalytics.visitorIDKey,
    ]

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
                analytics: NullAnalytics(),
                errorReporter: NullErrorReporter(),
                userDefaults: testHostDefaults,
                configuration: configuration
            )
        }

        let errorReporter = errorReporter(
            environment: environment,
            configuration: configuration,
            factory: makeErrorReporter
        )
        errorReporter.start()

        // Read on every event, so the Settings switch applies at once.
        let store = UserDefaultsPreferencesStore(defaults: userDefaults)
        let analytics: any Analytics = if !environment.isDebug, let apiKey = configuration.himetricaAPIKey {
            makeHimetrica(apiKey) { store.bool(for: SettingsViewModel.usageStatisticsKey) ?? true }
        } else {
            NullAnalytics()
        }

        return AppServices(
            analytics: analytics,
            errorReporter: errorReporter,
            userDefaults: userDefaults,
            configuration: configuration
        )
    }

    /// The main window's state. The test host and previews get inert services over folders that
    /// do not exist, so the window opens and measures without reading this Mac or running `simctl`.
    /// `legacyPreferences` reads the 0.7 domain; tests pass their own reader.
    static func makeCleanerViewModel(
        environment: AppEnvironment,
        services: AppServices,
        loginItem: any LoginItemManaging = MainAppLoginItem(),
        legacyPreferences: () -> [String: Any]? = {
            PreferencesDomainMigrator.persistentDomain(named: PreferencesDomainMigrator.legacyDomain)
        }
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

        migratePreferences(
            services: services,
            categories: catalog.categories,
            loginItem: loginItem,
            legacyPreferences: legacyPreferences
        )

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

    /// The update check. The test host and previews never reach the network.
    static func makeUpdateViewModel(environment: AppEnvironment, services: AppServices) -> UpdateViewModel {
        let checker: any VersionChecking = environment.isRunningTests || environment.isRunningPreviews
            ? InertVersionChecker()
            : RemoteVersionChecker(url: services.configuration.versionFileURL)

        return UpdateViewModel(
            currentVersion: services.configuration.version ?? "",
            currentBuild: services.configuration.build ?? "",
            checker: checker,
            analytics: services.analytics,
            errorReporter: services.errorReporter
        )
    }

    /// The Simulators section. The test host and previews never run `simctl` nor `xcodebuild`, nor
    /// read Apple's catalog of runtimes (C35).
    static func makeSimulatorsViewModel(
        environment: AppEnvironment,
        services: AppServices,
        onDeleted: @escaping () async -> Void = {}
    ) -> SimulatorsViewModel {
        let isInert = environment.isRunningTests || environment.isRunningPreviews
        let simulators: any SimulatorManaging = isInert ? InertSimulatorManager() : SimctlSimulatorService()
        let downloader: any RuntimeDownloading = isInert ? InertRuntimeDownloader() : XcodebuildRuntimeDownloader()
        let versionSource: any RuntimeVersionProviding = if isInert {
            InertRuntimeVersionSource()
        } else {
            RuntimeVersionSource(
                sdks: XcodebuildSimulatorSDKReader(),
                fetcher: AppleRuntimeCatalogClient(),
                cache: FileRuntimeCatalogCache(
                    directory: runtimeCatalogCacheDirectory(bundleIdentifier: services.configuration.bundleIdentifier)
                ),
                now: { .now }
            )
        }

        return SimulatorsViewModel(
            simulators: simulators,
            downloader: downloader,
            versionSource: versionSource,
            analytics: services.analytics,
            onDeleted: onDeleted
        )
    }

    /// `~/Library/Caches/<bundle id>`, where the catalog of runtimes is kept (C35, R7).
    static func runtimeCatalogCacheDirectory(bundleIdentifier: String?) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL.homeDirectory.appending(path: "Library/Caches", directoryHint: .isDirectory)

        return caches.appending(path: bundleIdentifier ?? defaultBundleIdentifier, directoryHint: .isDirectory)
    }

    /// The menu bar icon's background measurement (C40) and its live measurement over FSEvents
    /// (C40 · tempo real). Nothing measures nor watches in the test host or in previews; the app
    /// starts the scheduler it gets, and nothing is watched before that.
    static func makeBackgroundMeasurementScheduler(
        environment: AppEnvironment,
        measuring: any BackgroundMeasuring & LiveMeasuring,
        isEnabled: @escaping () -> Bool,
        isBusy: @escaping () -> Bool
    ) -> BackgroundMeasurementScheduler? {
        guard !environment.isRunningTests, !environment.isRunningPreviews else { return nil }

        let live = LiveMeasurementScheduler(measuring: measuring, watcher: FSEventsChangeWatcher(), isBusy: isBusy)

        return BackgroundMeasurementScheduler(measuring: measuring, isEnabled: isEnabled, isBusy: isBusy, live: live)
    }

    // MARK: - Private Methods

    /// Before the view model, Settings, analytics or the app delegate read the domain: first the
    /// 0.7 domain is copied (C33), then v1 → v2. The outcome goes to Sentry without the keys.
    private static func migratePreferences(
        services: AppServices,
        categories: [CleanupCategory],
        loginItem: any LoginItemManaging,
        legacyPreferences: () -> [String: Any]?
    ) {
        // Built with the old id, the app would read and mark its own domain.
        if services.configuration.bundleIdentifier != PreferencesDomainMigrator.legacyDomain {
            PreferencesDomainMigrator(keys: legacyDomainKeys).migrate(
                into: services.userDefaults,
                legacy: legacyPreferences
            )
        }

        let store = UserDefaultsPreferencesStore(defaults: services.userDefaults)
        let outcome = PreferencesMigrator(categories: categories).migrate(store, loginItem: loginItem)

        if outcome.restoredCorruptedValueCount > 0 {
            services.errorReporter.breadcrumb(.preferencesRestored)
        }

        if outcome.loginItemFailure != nil {
            services.errorReporter.breadcrumb(.loginItemMigrationFailed)
        }
    }

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
