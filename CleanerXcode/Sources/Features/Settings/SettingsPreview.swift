//
//  SettingsPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

#if DEBUG
    import Foundation

    /// Settings over an in-memory store and a fake login item; nothing is registered or saved.
    enum SettingsPreview {

        // MARK: - Public Methods

        static func makeViewModel(loginItemStatus: LoginItemStatus = .enabled) -> SettingsViewModel {
            SettingsViewModel(
                store: PreviewSettingsStore(),
                loginItem: PreviewLoginItem(status: loginItemStatus),
                analytics: NullAnalytics()
            )
        }

    }

    private final class PreviewSettingsStore: PreferencesStoring {

        // MARK: - Public Properties

        var schemaVersion: Int {
            PreferencesMigrator.currentSchemaVersion
        }

        // MARK: - Private Properties

        private var values: [String: Bool] = [:]
        private var integers: [String: Int] = [:]

        // MARK: - Public Methods

        func storedValue(for key: String) -> StoredBool {
            values[key].map(StoredBool.value) ?? .missing
        }

        func set(_ value: Bool, for key: String) {
            values[key] = value
        }

        func integer(for key: String) -> Int? {
            integers[key]
        }

        func set(_ value: Int, for key: String) {
            integers[key] = value
        }

        func removeValue(for key: String) {
            values[key] = nil
        }

        func setSchemaVersion(_ version: Int) {}

    }

    private struct PreviewLoginItem: LoginItemManaging {

        // MARK: - Public Properties

        let status: LoginItemStatus

        var isEnabled: Bool {
            status == .enabled
        }

        // MARK: - Public Methods

        func setEnabled(_ enabled: Bool) throws {}

    }
#endif
