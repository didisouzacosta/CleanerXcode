//
//  UserDefaultsPreferencesStoreTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Each test owns a fixed suite, seeded with the legacy encoding: `Data` holding JSON for `Bool`.
struct UserDefaultsPreferencesStoreTests {

    // MARK: - Public Methods

    @Test
    func readsTheLegacyEncodingAndTellsMissingFromCorruptedValues() throws {
        let name = "store.reads"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        try defaults.set(JSONEncoder().encode(true), forKey: "remove-archives")
        try defaults.set(JSONEncoder().encode(false), forKey: "remove-derived-data")
        defaults.set("yes", forKey: "remove-caches")
        defaults.set(Data("garbage".utf8), forKey: "clear-device-support")
        let store = UserDefaultsPreferencesStore(defaults: defaults)

        #expect(store.storedValue(for: "remove-archives") == .value(true))
        #expect(store.isSelected(.removeDerivedData) == false)
        #expect(store.storedValue(for: "remove-caches") == .corrupted)
        #expect(store.storedValue(for: "clear-device-support") == .corrupted)
        #expect(store.storedValue(for: "clear-simulator-data") == .missing)
        #expect(store.bool(for: "clear-simulator-data") == nil)
    }

    /// The 0.7 app reads what 1.0 writes, so going back a version keeps the choices.
    @Test
    func writesTheSameEncodingTheLegacyAppReads() throws {
        let name = "store.writes"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        let store = UserDefaultsPreferencesStore(defaults: defaults)

        store.setSelected(.removeArchives, false)
        store.set(true, for: "show-menu-bar-extra")
        let legacy = try #require(defaults.data(forKey: "remove-archives"))

        #expect(try JSONDecoder().decode(Bool.self, from: legacy) == false)
        #expect(store.bool(for: "show-menu-bar-extra") == true)
    }

    @Test
    func keepsTheSchemaVersionAndRemovesValues() {
        let name = "store.schema"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        let store = UserDefaultsPreferencesStore(defaults: defaults)

        #expect(store.schemaVersion == 0)

        store.setSchemaVersion(2)
        store.set(true, for: "launch-at-login")
        store.removeValue(for: "launch-at-login")

        #expect(store.schemaVersion == 2)
        #expect(defaults.integer(forKey: "preferences-schema-version") == 2)
        #expect(store.storedValue(for: "launch-at-login") == .missing)
    }

    /// Numbers, such as the minimum age of the temporary items, are plain integers.
    @Test
    func readsAndWritesIntegers() {
        let name = "store.integers"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        let store = UserDefaultsPreferencesStore(defaults: defaults)

        #expect(store.integer(for: "days") == nil)

        store.set(7, for: "days")

        #expect(store.integer(for: "days") == 7)
        #expect(defaults.integer(forKey: "days") == 7)

        defaults.set("seven", forKey: "days")

        #expect(store.integer(for: "days") == nil)
    }

}
