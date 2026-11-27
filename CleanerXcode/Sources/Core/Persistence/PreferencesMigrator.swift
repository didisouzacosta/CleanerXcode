//
//  PreferencesMigrator.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// v1 → v2, once (plan section 9). Every saved choice is kept; only missing or unreadable keys
/// get the new defaults (D5), and the legacy "launch at login" choice is handed to `SMAppService`
/// a single time. The decisions are pure; the store and the login item are injected.
struct PreferencesMigrator {

    // MARK: - Public Properties

    static let currentSchemaVersion = 2
    /// The new switch for the menu bar item, on by default.
    static let showMenuBarExtraKey = "show-menu-bar-extra"
    /// Same key as 0.7, now read as "show the size in the menu bar".
    static let showSizeInMenuBarKey = "display-free-up-space-in-menu-bar"
    /// Only read here: from now on `SMAppService` is the source of truth (R15).
    static let legacyLaunchAtLoginKey = "launch-at-login"

    let categories: [CleanupCategory]

    // MARK: - Public Methods

    @discardableResult
    func migrate(_ store: any PreferencesStoring, loginItem: any LoginItemManaging) -> Outcome {
        guard store.schemaVersion < Self.currentSchemaVersion else {
            return Outcome(didMigrate: false, restoredCorruptedValueCount: 0, loginItemFailure: nil)
        }

        var corruptedCount = 0

        let defaults = categories.map { ($0.id.rawValue, $0.isEnabledByDefault) }
            + [(Self.showMenuBarExtraKey, true), (Self.showSizeInMenuBarKey, true)]

        for (key, defaultValue) in defaults {
            switch store.storedValue(for: key) {
            case .value:
                continue
            case .missing:
                store.set(defaultValue, for: key)
            case .corrupted:
                corruptedCount += 1
                store.set(defaultValue, for: key)
            }
        }

        let launchAtLogin = migrateLaunchAtLogin(store, loginItem: loginItem)

        store.setSchemaVersion(Self.currentSchemaVersion)

        return Outcome(
            didMigrate: true,
            restoredCorruptedValueCount: corruptedCount + (launchAtLogin.isCorrupted ? 1 : 0),
            loginItemFailure: launchAtLogin.failure
        )
    }

    // MARK: - Private Methods

    /// Registers only when the user had it on and it is not registered yet. A missing or
    /// unreadable key means 0.7 was registering on every launch already, so nothing is done. The
    /// key itself is kept: the schema version makes sure it is read only once (R15), and going
    /// back to 0.7 keeps the user's choice. A failure is reported without stopping the migration.
    private func migrateLaunchAtLogin(
        _ store: any PreferencesStoring,
        loginItem: any LoginItemManaging
    ) -> (isCorrupted: Bool, failure: CleanupError?) {
        let legacy = store.storedValue(for: Self.legacyLaunchAtLoginKey)

        guard legacy == .value(true), loginItem.status == .notRegistered else {
            return (legacy == .corrupted, nil)
        }

        do {
            try loginItem.setEnabled(true)
            return (false, nil)
        } catch {
            return (false, CleanupError(error))
        }
    }

    // MARK: - Nested Types

    /// `restoredCorruptedValueCount` feeds a breadcrumb without the keys.
    struct Outcome: Equatable {
        let didMigrate: Bool
        let restoredCorruptedValueCount: Int
        let loginItemFailure: CleanupError?
    }

}
