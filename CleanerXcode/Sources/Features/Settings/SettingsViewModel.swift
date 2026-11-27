//
//  SettingsViewModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Observation

/// The General and About tabs (R14, R15, R17, D7). Every switch is kept in the preferences store;
/// "open at login" always shows what `SMAppService` reports, also after a failure.
@Observable
final class SettingsViewModel {

    // MARK: - Public Properties

    static let minimumAgeKey = "temporary-minimum-age-days"
    /// The legacy key: on by default, read by the analytics adapter on every event.
    static let usageStatisticsKey = "send-anonymous-analytics"
    static let minimumAgeOptions = [1, 3, 7, 14]

    /// Read by the composition tests.
    let loginItem: any LoginItemManaging

    private(set) var launchAtLogin = false
    /// macOS asks the user to allow it in System Settings › General › Login Items.
    private(set) var loginItemNeedsApproval = false
    private(set) var loginItemFailure: CleanupError?
    private(set) var showsMenuBarExtra: Bool
    private(set) var showsSizeInMenuBar: Bool
    private(set) var minimumTemporaryAgeInDays: Int
    private(set) var sendsUsageStatistics: Bool

    // MARK: - Private Properties

    private let store: any PreferencesStoring
    private let analytics: any Analytics
    private let onMinimumAgeChanged: (Int) -> Void

    // MARK: - Initializers

    /// `onMinimumAgeChanged` hands a new minimum age to the cleaner.
    init(
        store: any PreferencesStoring,
        loginItem: any LoginItemManaging,
        analytics: any Analytics,
        onMinimumAgeChanged: @escaping (Int) -> Void = { _ in }
    ) {
        self.store = store
        self.loginItem = loginItem
        self.analytics = analytics
        self.onMinimumAgeChanged = onMinimumAgeChanged
        self.showsMenuBarExtra = store.bool(for: PreferencesMigrator.showMenuBarExtraKey) ?? true
        self.showsSizeInMenuBar = store.bool(for: PreferencesMigrator.showSizeInMenuBarKey) ?? true
        self.minimumTemporaryAgeInDays = Self.storedMinimumAge(in: store)
        self.sendsUsageStatistics = store.bool(for: Self.usageStatisticsKey) ?? true

        readLoginItem()
    }

    // MARK: - Public Methods

    /// One of the offered values, or the default (D7).
    static func storedMinimumAge(in store: any PreferencesStoring) -> Int {
        guard let days = store.integer(for: minimumAgeKey), minimumAgeOptions.contains(days) else {
            return TemporaryItemsPolicy.defaultMinimumAgeInDays
        }

        return days
    }

    /// `SMAppService` errors stay generic ("Unknown error"); a register that ends waiting for
    /// approval shows only the guidance.
    func setLaunchAtLogin(_ isOn: Bool) {
        do {
            try loginItem.setEnabled(isOn)
            loginItemFailure = nil
        } catch {
            loginItemFailure = CleanupError(error)
        }

        readLoginItem()

        if loginItemNeedsApproval {
            loginItemFailure = nil
        }
    }

    /// Reads the status again, such as after the user allowed it in System Settings. Waiting for
    /// approval shows as on, so the item can still be turned off from here.
    func readLoginItem() {
        loginItemNeedsApproval = loginItem.status == .requiresApproval
        launchAtLogin = loginItem.isEnabled || loginItemNeedsApproval
    }

    func setShowsMenuBarExtra(_ isOn: Bool) {
        showsMenuBarExtra = isOn
        store.set(isOn, for: PreferencesMigrator.showMenuBarExtraKey)
    }

    func setShowsSizeInMenuBar(_ isOn: Bool) {
        showsSizeInMenuBar = isOn
        store.set(isOn, for: PreferencesMigrator.showSizeInMenuBarKey)
    }

    func setMinimumTemporaryAgeInDays(_ days: Int) {
        guard Self.minimumAgeOptions.contains(days), days != minimumTemporaryAgeInDays else { return }

        minimumTemporaryAgeInDays = days
        store.set(days, for: Self.minimumAgeKey)
        onMinimumAgeChanged(days)
    }

    func setSendsUsageStatistics(_ isOn: Bool) {
        sendsUsageStatistics = isOn
        store.set(isOn, for: Self.usageStatisticsKey)
    }

    func logDonation() {
        analytics.log(.donate)
    }

    func logSocial(_ social: AnalyticsEvent.Social) {
        analytics.log(.social(social))
    }

}
