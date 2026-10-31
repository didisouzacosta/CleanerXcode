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
        let analytics: any Analytics = if !environment.isDebug, let apiKey = configuration.himetricaAPIKey {
            makeHimetrica(apiKey) { preferences.sendAnonymousAnalytics.value }
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
