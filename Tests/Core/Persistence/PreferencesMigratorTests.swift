//
//  PreferencesMigratorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

@MainActor
struct PreferencesMigratorTests {

    // MARK: - Private Properties

    private let migrator = PreferencesMigrator(categories: CleanupCatalog(locations: .current()).categories)

    // MARK: - Public Methods

    @Test
    func keepsEverySavedChoiceAndGivesTheNewDefaultsOnlyToMissingKeys() {
        let store = InMemoryPreferencesStore([
            "remove-archives": .value(true),
            "remove-derived-data": .value(false),
            "clear-simulator-data": .value(true),
        ])

        migrator.migrate(store, loginItem: LoginItemSpy(status: .enabled))

        #expect(store.isSelected(.removeArchives) == true, "A saved choice wins over the new default.")
        #expect(store.isSelected(.removeDerivedData) == false)
        #expect(store.isSelected(.clearSimulatorData) == true)
        #expect(store.isSelected(.removeCaches) == true)
        #expect(store.isSelected(.resetXcodePreferences) == false)
        #expect(store.isSelected(.clearOrphanSimulatorTemp) == true)
        #expect(store.isSelected(.clearTemporaryFiles) == false)
        #expect(store.isSelected(.removeXcodeUserData) == false)
    }

    /// D5: Archives now comes off for whoever never touched it.
    @Test
    func archivesComeOffForWhoeverNeverTouchedThem() {
        let store = InMemoryPreferencesStore()

        migrator.migrate(store, loginItem: LoginItemSpy(status: .notRegistered))

        #expect(store.isSelected(.removeArchives) == false)
    }

    @Test
    func showsTheMenuBarExtraByDefaultAndKeepsTheSizeChoice() {
        let store = InMemoryPreferencesStore(["display-free-up-space-in-menu-bar": .value(false)])

        migrator.migrate(store, loginItem: LoginItemSpy(status: .enabled))

        #expect(store.bool(for: "show-menu-bar-extra") == true)
        #expect(store.bool(for: "display-free-up-space-in-menu-bar") == false)
    }

    @Test
    func registersTheLoginItemOnceWhenTheLegacyChoiceWasOnAndItIsNotRegistered() {
        let store = InMemoryPreferencesStore(["launch-at-login": .value(true)])
        let loginItem = LoginItemSpy(status: .notRegistered)

        let outcome = migrator.migrate(store, loginItem: loginItem)
        migrator.migrate(store, loginItem: loginItem)

        #expect(loginItem.requests == [true])
        #expect(outcome.didMigrate)
        #expect(store.bool(for: "launch-at-login") == true, "Kept so going back to 0.7 keeps the choice.")
    }

    @Test(arguments: [
        (StoredBool.value(true), LoginItemStatus.enabled),
        (.value(true), .requiresApproval),
        (.value(false), .notRegistered),
        (.missing, .notRegistered),
    ])
    func leavesTheLoginItemAloneOtherwise(legacy: StoredBool, status: LoginItemStatus) {
        let loginItem = LoginItemSpy(status: status)

        migrator.migrate(InMemoryPreferencesStore(["launch-at-login": legacy]), loginItem: loginItem)

        #expect(loginItem.requests.isEmpty)
    }

    @Test
    func aFailedRegistrationIsReportedAndTheMigrationStillFinishes() {
        let store = InMemoryPreferencesStore(["launch-at-login": .value(true)])

        let outcome = migrator.migrate(
            store,
            loginItem: LoginItemSpy(status: .notRegistered, failure: .permissionDenied)
        )

        #expect(outcome.loginItemFailure == .permissionDenied)
        #expect(store.schemaVersion == PreferencesMigrator.currentSchemaVersion)
    }

    /// 0.7 registered on every launch with a missing or unreadable key, so nothing is registered.
    @Test
    func aCorruptedLaunchAtLoginIsCountedAndNeverRegisters() {
        let store = InMemoryPreferencesStore(["launch-at-login": .corrupted])
        let loginItem = LoginItemSpy(status: .notRegistered)

        let outcome = migrator.migrate(store, loginItem: loginItem)

        #expect(outcome.restoredCorruptedValueCount == 1)
        #expect(loginItem.requests.isEmpty)
    }

    @Test
    func keepsTheLegacyLaunchAtLoginChoiceForADowngrade() {
        let store = InMemoryPreferencesStore(["launch-at-login": .value(false)])

        migrator.migrate(store, loginItem: LoginItemSpy(status: .notRegistered))

        #expect(store.bool(for: "launch-at-login") == false)
    }

    @Test
    func aCorruptedValueGoesBackToItsDefaultWithoutCrashing() {
        let store = InMemoryPreferencesStore(["remove-derived-data": .corrupted, "show-menu-bar-extra": .corrupted])

        let outcome = migrator.migrate(store, loginItem: LoginItemSpy(status: .enabled))

        #expect(store.isSelected(.removeDerivedData) == true)
        #expect(store.bool(for: "show-menu-bar-extra") == true)
        #expect(outcome.restoredCorruptedValueCount == 2)
    }

    @Test
    func runsOnlyOnceAndThenNeverWritesAgain() {
        let store = InMemoryPreferencesStore()

        let first = migrator.migrate(store, loginItem: LoginItemSpy(status: .enabled))
        let writes = store.writeCount
        let second = migrator.migrate(store, loginItem: LoginItemSpy(status: .enabled))

        #expect(first.didMigrate && !second.didMigrate)
        #expect(store.writeCount == writes)
        #expect(store.schemaVersion == 2 && PreferencesMigrator.currentSchemaVersion == 2)
    }

    @Test
    func migratesALegacySuiteEndToEnd() throws {
        let name = "migrator.endToEnd"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        try defaults.set(JSONEncoder().encode(true), forKey: "remove-archives")
        try defaults.set(JSONEncoder().encode(false), forKey: "remove-caches")
        let store = UserDefaultsPreferencesStore(defaults: defaults)

        migrator.migrate(store, loginItem: LoginItemSpy(status: .enabled))

        #expect(store.isSelected(.removeArchives) == true)
        #expect(store.isSelected(.removeCaches) == false)
        #expect(store.isSelected(.removeDerivedData) == true)
        #expect(defaults.integer(forKey: "preferences-schema-version") == 2)
    }

}
