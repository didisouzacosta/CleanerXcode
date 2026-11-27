//
//  UserDefaultsPreferencesStore.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Reads and writes switches with the legacy encoding (`Data` holding JSON for `Bool`), so the
/// choices saved by 0.7 survive and 0.7 can still read what 1.0 writes.
final class UserDefaultsPreferencesStore: PreferencesStoring {

    // MARK: - Public Properties

    static let schemaVersionKey = "preferences-schema-version"

    var schemaVersion: Int {
        defaults.integer(forKey: Self.schemaVersionKey)
    }

    // MARK: - Private Properties

    private let defaults: UserDefaults

    // MARK: - Initializers

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public Methods

    func storedValue(for key: String) -> StoredBool {
        guard let object = defaults.object(forKey: key) else { return .missing }

        guard let data = object as? Data, let value = try? JSONDecoder().decode(Bool.self, from: data) else {
            return .corrupted
        }

        return .value(value)
    }

    func set(_ value: Bool, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        defaults.set(data, forKey: key)
    }

    func integer(for key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }

    func set(_ value: Int, for key: String) {
        defaults.set(value, forKey: key)
    }

    func removeValue(for key: String) {
        defaults.removeObject(forKey: key)
    }

    func setSchemaVersion(_ version: Int) {
        defaults.set(version, forKey: Self.schemaVersionKey)
    }

}
