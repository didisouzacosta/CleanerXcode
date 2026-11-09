//
//  AppContainer+Demo.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    import Foundation

    /// The demo's view models (C36): mocked sizes over `CleanupLocations.inert`, a make-believe
    /// cleanup and the simulators of the previews. Nothing reads this Mac, runs `simctl` nor
    /// `xcodebuild`, or reaches the network.
    extension AppContainer {

        // MARK: - Public Methods

        static func makeDemoCleanerViewModel(services: AppServices) -> CleanerViewModel {
            let state = DemoDiskState()
            let store = UserDefaultsPreferencesStore(defaults: services.userDefaults)

            return CleanerViewModel(
                catalog: CleanupCatalog(locations: .inert),
                measurer: CategorySizeMeasurer(scanner: DemoDiskScanner(state: state)),
                simulators: DemoSimulatorManager(),
                executor: DemoCleanupExecutor(state: state),
                preferences: store,
                runningApplications: DemoRunningApplications(),
                analytics: services.analytics,
                errorReporter: services.errorReporter,
                appBundleIdentifier: services.configuration.bundleIdentifier ?? "",
                minimumTemporaryAgeInDays: SettingsViewModel.storedMinimumAge(in: store)
            )
        }

        static func makeDemoSimulatorsViewModel() -> SimulatorsViewModel {
            SimulatorsSectionPreview.makeViewModel(for: .loaded)
        }

    }
#endif
