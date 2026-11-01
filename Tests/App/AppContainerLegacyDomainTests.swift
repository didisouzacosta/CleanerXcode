//
//  AppContainerLegacyDomainTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// C33: the preferences saved under the 0.7 bundle id reach the new one before anything reads them.
/// Each test owns its suites and passes its own reader, so the real domains are never touched.
struct AppContainerLegacyDomainTests {

    // MARK: - Private Properties

    private let configuration = AppConfiguration(versionFileURL: nil)

    // MARK: - Public Methods

    /// C33 (D3): exactly the user's choices travel to the new bundle id.
    @Test
    func theLegacyDomainKeysAreTheUsersChoices() {
        let expected = Set(CleanupCategoryID.allCases.map(\.rawValue)).union([
            PreferencesMigrator.showSizeInMenuBarKey,
            PreferencesMigrator.showMenuBarExtraKey,
            SettingsViewModel.minimumAgeKey,
            SettingsViewModel.usageStatisticsKey,
            HimetricaAnalytics.visitorIDKey,
        ])
        let keys = AppContainer.legacyDomainKeys

        #expect(Set(keys) == expected)
        #expect(keys.count == expected.count, "No duplicates.")
        #expect(!keys.contains(UserDefaultsPreferencesStore.schemaVersionKey))
        #expect(!keys.contains(PreferencesDomainMigrator.markerKey))
        #expect(!keys.contains(PreferencesMigrator.legacyLaunchAtLoginKey))
        #expect(!keys.contains("hm_session_id"))
    }

    /// C33: the old domain is copied before the v1 → v2 migration, and saved values win over D5.
    @Test
    func outsideTestsTheLegacyDomainIsMigratedBeforeTheCleanerReadsIt() {
        let defaults = TestPreferencesDomain.defaults(named: "container.legacy")

        defer { TestPreferencesDomain.remove(named: "container.legacy") }

        let legacy: [String: Any] = [
            CleanupCategoryID.removeArchives.rawValue: Data.legacyPreference(true),
            CleanupCategoryID.clearDeviceSupport.rawValue: Data.legacyPreference(true),
            PreferencesMigrator.showSizeInMenuBarKey: Data.legacyPreference(false),
        ]

        let viewModel = AppContainer.makeCleanerViewModel(
            environment: AppEnvironment(isRunningTests: false, isDebug: true),
            services: services(userDefaults: defaults),
            loginItem: LoginItemSpy(status: .enabled),
            legacyPreferences: { legacy }
        )
        let store = UserDefaultsPreferencesStore(defaults: defaults)

        #expect(viewModel.selectedIDs.contains(.removeArchives), "The saved choice wins over D5.")
        #expect(viewModel.selectedIDs.contains(.clearDeviceSupport))
        #expect(store.bool(for: PreferencesMigrator.showSizeInMenuBarKey) == false)
        #expect(store.schemaVersion == PreferencesMigrator.currentSchemaVersion)
        #expect(defaults.integer(forKey: PreferencesDomainMigrator.markerKey) == PreferencesDomainMigrator
            .currentVersion)
    }

    /// C33 (D6): `SMAppService` is tied to the bundle id, so 0.7's login item is registered again.
    @Test(arguments: [(nil as Bool?, [true]), (false, [])])
    func theLoginItemFollowsThe07Choice(legacyChoice: Bool?, expectedRequests: [Bool]) {
        let name = "container.legacy.login.\(legacyChoice.map { "\($0)" } ?? "missing")"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        var legacy: [String: Any] = ["NSStatusItem Preferred Position Item-0": 120]

        if let legacyChoice {
            legacy[PreferencesMigrator.legacyLaunchAtLoginKey] = Data.legacyPreference(legacyChoice)
        }

        let loginItem = LoginItemSpy(status: .notRegistered)

        _ = AppContainer.makeCleanerViewModel(
            environment: AppEnvironment(isRunningTests: false, isDebug: true),
            services: services(userDefaults: defaults),
            loginItem: loginItem,
            legacyPreferences: { legacy }
        )

        #expect(loginItem.requests == expectedRequests)
    }

    @Test
    func testsAndPreviewsNeverReadTheLegacyDomain() {
        let defaults = TestPreferencesDomain.defaults(named: "container.legacy.inert")

        defer { TestPreferencesDomain.remove(named: "container.legacy.inert") }

        let environments = [
            AppEnvironment(isRunningTests: true, isDebug: true),
            AppEnvironment(isRunningTests: false, isRunningPreviews: true, isDebug: true),
        ]

        var reads = 0

        for environment in environments {
            _ = AppContainer.makeCleanerViewModel(
                environment: environment,
                services: services(userDefaults: defaults),
                loginItem: LoginItemSpy(status: .notRegistered),
                legacyPreferences: {
                    reads += 1
                    return [CleanupCategoryID.removeArchives.rawValue: Data.legacyPreference(true)]
                }
            )
        }

        #expect(reads == 0)
        #expect(defaults.object(forKey: PreferencesDomainMigrator.markerKey) == nil)
    }

    /// Built with the old id, the app would write the marker into the old domain itself.
    @Test
    func theOldBundleIdentifierNeverMigratesIntoItself() {
        let defaults = TestPreferencesDomain.defaults(named: "container.legacy.self")

        defer { TestPreferencesDomain.remove(named: "container.legacy.self") }

        var reads = 0

        _ = AppContainer.makeCleanerViewModel(
            environment: AppEnvironment(isRunningTests: false, isDebug: true),
            services: services(
                userDefaults: defaults,
                configuration: AppConfiguration(bundleIdentifier: PreferencesDomainMigrator.legacyDomain)
            ),
            loginItem: LoginItemSpy(status: .enabled),
            legacyPreferences: {
                reads += 1
                return nil
            }
        )

        #expect(reads == 0)
        #expect(defaults.object(forKey: PreferencesDomainMigrator.markerKey) == nil)
    }

    @Test
    func settingsMadeAfterwardsSeeTheMigratedValues() {
        let defaults = TestPreferencesDomain.defaults(named: "container.legacy.settings")

        defer { TestPreferencesDomain.remove(named: "container.legacy.settings") }

        let services = services(userDefaults: defaults)

        _ = AppContainer.makeCleanerViewModel(
            environment: AppEnvironment(isRunningTests: false, isDebug: true),
            services: services,
            loginItem: LoginItemSpy(status: .enabled),
            legacyPreferences: {
                [
                    PreferencesMigrator.showSizeInMenuBarKey: Data.legacyPreference(false),
                    SettingsViewModel.usageStatisticsKey: Data.legacyPreference(false),
                ]
            }
        )

        // The test environment keeps the real login item out of reach; the store is the same.
        let settings = AppContainer.makeSettingsViewModel(
            environment: AppEnvironment(isRunningTests: true, isDebug: true),
            services: services
        )

        #expect(settings.showsSizeInMenuBar == false)
        #expect(settings.sendsUsageStatistics == false)
    }

    @Test
    func analyticsFollowsTheMigratedOptOut() {
        let defaults = TestPreferencesDomain.defaults(named: "container.legacy.analytics")

        defer { TestPreferencesDomain.remove(named: "container.legacy.analytics") }

        let environment = AppEnvironment(isRunningTests: false, isDebug: false)
        let factory = AnalyticsSwitchCaptor()
        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(himetricaAPIKey: "hm_pk_test"),
            userDefaults: defaults,
            makeHimetrica: factory.make
        )

        #expect(factory.isEnabled?() == true, "On by default before the migration.")

        _ = AppContainer.makeCleanerViewModel(
            environment: environment,
            services: services,
            loginItem: LoginItemSpy(status: .enabled),
            legacyPreferences: { [SettingsViewModel.usageStatisticsKey: Data.legacyPreference(false)] }
        )

        #expect(factory.isEnabled?() == false)
    }

    /// R7: the old domain is never written nor removed, so going back to 0.7 keeps working.
    @Test
    func theLegacyDomainStaysUntouched() throws {
        let legacyName = "container.legacy.source"
        let legacyDefaults = TestPreferencesDomain.defaults(named: legacyName)
        let defaults = TestPreferencesDomain.defaults(named: "container.legacy.target")

        defer {
            TestPreferencesDomain.remove(named: legacyName)
            TestPreferencesDomain.remove(named: "container.legacy.target")
        }

        legacyDefaults.set(Data.legacyPreference(true), forKey: CleanupCategoryID.removeArchives.rawValue)
        legacyDefaults.set(7, forKey: SettingsViewModel.minimumAgeKey)
        legacyDefaults.set("frame", forKey: "NSWindow Frame cleaner")

        let legacyDomain = TestPreferencesDomain.prefix + legacyName
        let before = try #require(PreferencesDomainMigrator.persistentDomain(named: legacyDomain))

        _ = AppContainer.makeCleanerViewModel(
            environment: AppEnvironment(isRunningTests: false, isDebug: true),
            services: services(userDefaults: defaults),
            loginItem: LoginItemSpy(status: .enabled),
            legacyPreferences: { PreferencesDomainMigrator.persistentDomain(named: legacyDomain) }
        )

        let after = try #require(PreferencesDomainMigrator.persistentDomain(named: legacyDomain))

        #expect(NSDictionary(dictionary: before) == NSDictionary(dictionary: after))
        #expect(defaults.object(forKey: SettingsViewModel.minimumAgeKey) as? Int == 7, "It was read.")
    }

    // MARK: - Private Methods

    private func services(userDefaults: UserDefaults, configuration: AppConfiguration? = nil) -> AppServices {
        AppServices(
            analytics: NullAnalytics(),
            errorReporter: NullErrorReporter(),
            userDefaults: userDefaults,
            configuration: configuration ?? self.configuration
        )
    }

}

/// Keeps the "send usage statistics" check the container hands to Himetrica.
private final class AnalyticsSwitchCaptor {

    // MARK: - Public Properties

    private(set) var isEnabled: (() -> Bool)?

    // MARK: - Public Methods

    func make(apiKey: String, isEnabled: @escaping () -> Bool) -> any Analytics {
        self.isEnabled = isEnabled
        return NullAnalytics()
    }

}
