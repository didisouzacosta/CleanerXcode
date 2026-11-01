//
//  PreferencesDomainMigrator.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation

/// Up to 0.7 the app was `didisouzacosta.CleanerXcode`; from 1.0 it is
/// `com.didisouzacosta.CleanerXcode`, so its `UserDefaults` domain starts empty (C33). Once, before
/// `PreferencesMigrator`, the user's choices are copied raw from the old domain: only the listed
/// keys, never over a value the new domain already has. The old domain is never written nor
/// removed, so going back to 0.7 keeps working. The schema version is not copied: v1 → v2 runs
/// again under the new id, keeps every copied value and hands the login item to `SMAppService`,
/// which is tied to the bundle id.
struct PreferencesDomainMigrator {

    // MARK: - Public Properties

    static let legacyDomain = "didisouzacosta.CleanerXcode"
    static let markerKey = "legacy-domain-migration-version"
    static let currentVersion = 1

    /// Raw copies, so the 0.7 encoding (and an unreadable value) reaches `PreferencesMigrator`.
    let keys: [String]

    // MARK: - Public Methods

    /// Only what was saved in that domain: unlike `UserDefaults(suiteName:)`, no argument or
    /// global keys. `nil` when the domain does not exist or is empty.
    static func persistentDomain(named name: String, in defaults: UserDefaults = .standard) -> [String: Any]? {
        guard let domain = defaults.persistentDomain(forName: name), !domain.isEmpty else { return nil }

        return domain
    }

    /// `readLegacy` is called only while the marker is missing.
    @discardableResult
    func migrate(into defaults: UserDefaults, legacy readLegacy: () -> [String: Any]?) -> Outcome {
        guard defaults.integer(forKey: Self.markerKey) < Self.currentVersion else { return .alreadyMigrated }

        let legacy = readLegacy() ?? [:]

        guard !legacy.isEmpty else {
            defaults.set(Self.currentVersion, forKey: Self.markerKey)
            return .noLegacyDomain
        }

        for key in keys where defaults.object(forKey: key) == nil {
            guard let value = legacy[key] else { continue }

            defaults.set(value, forKey: key)
        }

        migrateLaunchAtLogin(from: legacy, into: defaults)

        defaults.set(Self.currentVersion, forKey: Self.markerKey)
        return .migrated
    }

    // MARK: - Private Methods

    /// From 0.7 the choice is copied as it is, and a missing key becomes `true`: 0.7 registered the
    /// login item on every launch while the key was missing. From a 1.0 development build the key
    /// is stale, because `SMAppService` became the source of truth, so nothing is written.
    private func migrateLaunchAtLogin(from legacy: [String: Any], into defaults: UserDefaults) {
        let key = PreferencesMigrator.legacyLaunchAtLoginKey
        let legacySchema = legacy[UserDefaultsPreferencesStore.schemaVersionKey] as? Int ?? 0

        guard defaults.object(forKey: key) == nil, legacySchema < PreferencesMigrator.currentSchemaVersion else {
            return
        }

        if let value = legacy[key] {
            defaults.set(value, forKey: key)
        } else {
            UserDefaultsPreferencesStore(defaults: defaults).set(true, for: key)
        }
    }

    // MARK: - Nested Types

    enum Outcome: Equatable {
        case alreadyMigrated
        case noLegacyDomain
        case migrated
    }

}
