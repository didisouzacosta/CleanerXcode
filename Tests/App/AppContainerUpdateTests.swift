//
//  AppContainerUpdateTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Which updater each build gets (C42): Sparkle in a configured Release, `version.json` in any
/// other build, nothing in the test host and previews. Only the types are checked: no updater
/// starts or reaches the network in a test.
struct AppContainerUpdateTests {

    // MARK: - Private Properties

    private let sparkleConfiguration = AppConfiguration(
        versionFileURL: URL(string: "https://updates.invalid/version.json"),
        sparkleFeedURL: URL(string: "https://downloads.invalid/appcast.xml"),
        sparklePublicKey: "pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ="
    )

    // MARK: - Public Methods

    @Test
    func testsNeverCheckForUpdatesOverTheNetwork() {
        let environment = AppEnvironment(isRunningTests: true, isDebug: true)
        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(versionFileURL: URL(string: "https://updates.invalid/version.json"))
        )

        let viewModel = AppContainer.makeUpdateViewModel(environment: environment, services: services)

        #expect(viewModel.updater is InertSoftwareUpdater)
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

        #expect((appViewModel.updater as? VersionFileUpdater)?.checker is RemoteVersionChecker)
        #expect(previewViewModel.updater is InertSoftwareUpdater)
    }

    /// C42: only a Release build with the feed and the key installs updates with Sparkle. Only the
    /// type is checked; the updater never starts in a test.
    @Test
    func aConfiguredReleaseUsesSparkle() {
        let release = AppEnvironment(isRunningTests: false, isDebug: false)
        let services = AppServices(
            analytics: NullAnalytics(),
            errorReporter: NullErrorReporter(),
            userDefaults: .test,
            configuration: sparkleConfiguration
        )

        let viewModel = AppContainer.makeUpdateViewModel(environment: release, services: services)

        #expect(viewModel.updater is SparkleSoftwareUpdater)
        #expect(viewModel.canCheckForUpdates)
    }

    /// A Debug build shares the bundle id: Sparkle would replace it with the published Release.
    @Test
    func debugAndUnconfiguredBuildsKeepTheVersionFile() {
        let debug = AppEnvironment(isRunningTests: false, isDebug: true)
        let release = AppEnvironment(isRunningTests: false, isDebug: false)
        let unconfigured = AppConfiguration(versionFileURL: URL(string: "https://updates.invalid/version.json"))

        let debugViewModel = AppContainer.makeUpdateViewModel(
            environment: debug,
            services: AppServices(
                analytics: NullAnalytics(),
                errorReporter: NullErrorReporter(),
                userDefaults: .test,
                configuration: sparkleConfiguration
            )
        )
        let releaseViewModel = AppContainer.makeUpdateViewModel(
            environment: release,
            services: AppServices(
                analytics: NullAnalytics(),
                errorReporter: NullErrorReporter(),
                userDefaults: .test,
                configuration: unconfigured
            )
        )

        #expect(debugViewModel.updater is VersionFileUpdater)
        #expect(releaseViewModel.updater is VersionFileUpdater)
        #expect(releaseViewModel.canCheckForUpdates == false)
    }

}
