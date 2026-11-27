//
//  PreferencesDomainMigratorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The destination is a test suite owned by each test; the legacy domain is a literal dictionary
/// in the 0.7 encoding (`Data` holding JSON for `Bool`). The real domains are never read.
@MainActor
struct PreferencesDomainMigratorTests {

    // MARK: - Private Properties

    private let migrator = PreferencesDomainMigrator(keys: AppContainer.legacyDomainKeys)
    private let launchAtLoginKey = PreferencesMigrator.legacyLaunchAtLoginKey

    // MARK: - Public Methods

    @Test
    func copiesEveryListedKeyKeepingItsEncoding() throws {
        let defaults = TestPreferencesDomain.defaults(named: "domain.copy")

        defer { TestPreferencesDomain.remove(named: "domain.copy") }

        var legacy: [String: Any] = [:]

        for id in CleanupCategoryID.allCases {
            legacy[id.rawValue] = Data.legacyPreference(true)
        }

        legacy[PreferencesMigrator.showSizeInMenuBarKey] = Data.legacyPreference(false)
        legacy[PreferencesMigrator.showMenuBarExtraKey] = Data.legacyPreference(false)
        legacy[SettingsViewModel.minimumAgeKey] = 14
        legacy[SettingsViewModel.usageStatisticsKey] = Data.legacyPreference(false)
        legacy[HimetricaAnalytics.visitorIDKey] = "visitor-1"

        let outcome = migrator.migrate(into: defaults) { legacy }

        #expect(outcome == .migrated)
        #expect(legacy.count == 20, "15 categories, two menu bar switches, the age, the opt-out and the visitor.")

        for (key, value) in legacy {
            let copied = try #require(defaults.object(forKey: key) as? NSObject, "\(key)")

            #expect(copied == value as? NSObject, "\(key)")
        }

        #expect(defaults.data(forKey: CleanupCategoryID.removeArchives.rawValue) == Data.legacyPreference(true))
        #expect(defaults.object(forKey: SettingsViewModel.minimumAgeKey) as? Int == 14)
        #expect(defaults.string(forKey: HimetricaAnalytics.visitorIDKey) == "visitor-1")
    }

    @Test
    func neverOverwritesAValueTheNewDomainAlreadyHas() {
        let defaults = TestPreferencesDomain.defaults(named: "domain.keep")

        defer { TestPreferencesDomain.remove(named: "domain.keep") }

        defaults.set(Data.legacyPreference(false), forKey: CleanupCategoryID.removeArchives.rawValue)
        defaults.set(3, forKey: SettingsViewModel.minimumAgeKey)
        defaults.set(Data.legacyPreference(false), forKey: launchAtLoginKey)

        migrator.migrate(into: defaults) {
            [
                CleanupCategoryID.removeArchives.rawValue: Data.legacyPreference(true),
                CleanupCategoryID.removeCaches.rawValue: Data.legacyPreference(false),
                SettingsViewModel.minimumAgeKey: 14,
                launchAtLoginKey: Data.legacyPreference(true),
            ]
        }

        #expect(defaults.data(forKey: CleanupCategoryID.removeArchives.rawValue) == Data.legacyPreference(false))
        #expect(defaults.object(forKey: SettingsViewModel.minimumAgeKey) as? Int == 3)
        #expect(defaults.data(forKey: launchAtLoginKey) == Data.legacyPreference(false))
        #expect(
            defaults.data(forKey: CleanupCategoryID.removeCaches.rawValue) == Data.legacyPreference(false),
            "Missing ones still come."
        )
    }

    @Test
    func leavesWindowStateSystemKeysOrphansAndSessionsBehind() {
        let defaults = TestPreferencesDomain.defaults(named: "domain.skip")

        defer { TestPreferencesDomain.remove(named: "domain.skip") }

        let skipped = [
            "NSWindow Frame cleaner",
            "NSSplitView Subview Frames cleaner",
            "com_apple_SwiftUI_Settings_selectedTabIndex",
            "section-collapsed-xcode",
            "simulators-list-expanded",
            "hm_session_id",
            "hm_session_timestamp",
            "hm_original_referrer",
            "NSStatusItem Preferred Position Item-0",
            "AppleLocale",
        ]

        var legacy: [String: Any] = [CleanupCategoryID.removeCaches.rawValue: Data.legacyPreference(true)]

        for key in skipped {
            legacy[key] = "value"
        }

        migrator.migrate(into: defaults) { legacy }

        // The saved domain, not the suite: a suite also reads the global keys such as `AppleLocale`.
        let saved = UserDefaults.standard.persistentDomain(forName: TestPreferencesDomain.prefix + "domain.skip") ?? [:]

        for key in skipped {
            #expect(saved[key] == nil, "\(key)")
        }

        #expect(saved[CleanupCategoryID.removeCaches.rawValue] as? Data == Data.legacyPreference(true))
    }

    /// The schema describes the domain it lives in, so v1 → v2 runs again under the new id.
    @Test
    func neverCopiesTheSchemaVersion() {
        let defaults = TestPreferencesDomain.defaults(named: "domain.schema")

        defer { TestPreferencesDomain.remove(named: "domain.schema") }

        migrator.migrate(into: defaults) {
            [
                UserDefaultsPreferencesStore.schemaVersionKey: 2,
                CleanupCategoryID.removeCaches.rawValue: Data.legacyPreference(true),
            ]
        }

        #expect(defaults.object(forKey: UserDefaultsPreferencesStore.schemaVersionKey) == nil)
        #expect(UserDefaultsPreferencesStore(defaults: defaults).schemaVersion == 0)
        #expect(
            defaults.data(forKey: CleanupCategoryID.removeCaches.rawValue) == Data.legacyPreference(true),
            "The rest comes."
        )
    }

    @Test
    func runsOnceAndThenNeverReadsTheLegacyDomainAgain() {
        let defaults = TestPreferencesDomain.defaults(named: "domain.once")

        defer { TestPreferencesDomain.remove(named: "domain.once") }

        var legacy: [String: Any] = [CleanupCategoryID.removeArchives.rawValue: Data.legacyPreference(true)]
        var reads = 0

        let first = migrator.migrate(into: defaults) {
            reads += 1
            return legacy
        }

        defaults.removeObject(forKey: CleanupCategoryID.removeArchives.rawValue)
        legacy[CleanupCategoryID.removeCaches.rawValue] = Data.legacyPreference(true)

        let second = migrator.migrate(into: defaults) {
            reads += 1
            return legacy
        }

        #expect(first == .migrated)
        #expect(second == .alreadyMigrated)
        #expect(reads == 1)
        #expect(defaults.integer(forKey: PreferencesDomainMigrator.markerKey) == PreferencesDomainMigrator
            .currentVersion)
        #expect(defaults.object(forKey: CleanupCategoryID.removeArchives.rawValue) == nil)
        #expect(defaults.object(forKey: CleanupCategoryID.removeCaches.rawValue) == nil)
    }

    /// A fresh install: only the marker is written.
    @Test(arguments: [true, false])
    func withoutALegacyDomainOnlyTheMarkerIsWritten(isMissing: Bool) {
        let name = "domain.fresh.\(isMissing)"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        let outcome = migrator.migrate(into: defaults) { isMissing ? nil : [:] }
        let domain = UserDefaults.standard.persistentDomain(forName: TestPreferencesDomain.prefix + name) ?? [:]

        #expect(outcome == .noLegacyDomain)
        #expect(Array(domain.keys) == [PreferencesDomainMigrator.markerKey])
        #expect(defaults.integer(forKey: PreferencesDomainMigrator.markerKey) == PreferencesDomainMigrator
            .currentVersion)
    }

    /// 0.7 registered the login item on every launch while the key was missing.
    @Test
    func a07DomainWithoutTheLoginChoiceTurnsItOn() {
        let defaults = TestPreferencesDomain.defaults(named: "domain.login.missing")

        defer { TestPreferencesDomain.remove(named: "domain.login.missing") }

        migrator.migrate(into: defaults) { ["NSStatusItem Preferred Position Item-0": 120] }

        #expect(defaults.data(forKey: launchAtLoginKey) == Data.legacyPreference(true))
        #expect(UserDefaultsPreferencesStore(defaults: defaults).storedValue(for: launchAtLoginKey) == .value(true))
    }

    @Test(arguments: LegacyLaunchValue.allCases)
    func a07LoginChoiceIsCopiedAsItIs(value: LegacyLaunchValue) throws {
        let name = "domain.login.\(value)"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        migrator.migrate(into: defaults) { [launchAtLoginKey: value.object] }

        let copied = try #require(defaults.object(forKey: launchAtLoginKey) as? NSObject)

        #expect(copied == value.object as? NSObject)
    }

    /// From a 1.0 development build `SMAppService` is the source of truth, so the key is stale.
    @Test
    func aV2DomainNeverCopiesNorTurnsOnTheLoginChoice() {
        let defaults = TestPreferencesDomain.defaults(named: "domain.login.v2")

        defer { TestPreferencesDomain.remove(named: "domain.login.v2") }

        migrator.migrate(into: defaults) {
            [
                UserDefaultsPreferencesStore.schemaVersionKey: 2,
                CleanupCategoryID.removeCaches.rawValue: Data.legacyPreference(false),
                launchAtLoginKey: Data.legacyPreference(true),
            ]
        }

        #expect(defaults.object(forKey: launchAtLoginKey) == nil)
        #expect(
            defaults.data(forKey: CleanupCategoryID.removeCaches.rawValue) == Data.legacyPreference(false),
            "The rest comes."
        )

        let withoutTheKey = TestPreferencesDomain.defaults(named: "domain.login.v2.missing")

        defer { TestPreferencesDomain.remove(named: "domain.login.v2.missing") }

        migrator.migrate(into: withoutTheKey) { [UserDefaultsPreferencesStore.schemaVersionKey: 2] }

        #expect(withoutTheKey.object(forKey: launchAtLoginKey) == nil)
    }

    @Test
    func readsOnlyWhatWasSavedInTheNamedDomain() throws {
        let name = "domain.read"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        defaults.set(Data.legacyPreference(true), forKey: CleanupCategoryID.removeArchives.rawValue)

        let domain = try #require(PreferencesDomainMigrator
            .persistentDomain(named: TestPreferencesDomain.prefix + name))

        #expect(Array(domain.keys) == [CleanupCategoryID.removeArchives.rawValue])
        #expect(domain["AppleLocale"] == nil, "The global domain is not part of it.")
        #expect(domain[CleanupCategoryID.removeArchives.rawValue] as? Data == Data.legacyPreference(true))
    }

    @Test
    func aDomainThatDoesNotExistReadsAsNil() {
        let name = "domain.read.missing"

        TestPreferencesDomain.remove(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        #expect(PreferencesDomainMigrator.persistentDomain(named: TestPreferencesDomain.prefix + name) == nil)
    }

    // MARK: - Nested Types

    /// What 0.7 may have saved for "launch at login", readable or not.
    nonisolated enum LegacyLaunchValue: CaseIterable, Sendable {

        // MARK: - Cases

        case enabled
        case disabled
        case garbage
        case text

        // MARK: - Public Properties

        var object: Any {
            switch self {
            case .enabled:
                Data.legacyPreference(true)

            case .disabled:
                Data.legacyPreference(false)

            case .garbage:
                Data("garbage".utf8)

            case .text:
                "yes"
            }
        }
    }

}
