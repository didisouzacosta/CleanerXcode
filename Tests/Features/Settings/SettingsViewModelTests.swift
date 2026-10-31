//
//  SettingsViewModelTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

/// Settings (R14, R15, R17, D7): every switch is kept in the store, the login item is the source
/// of truth for "open at login", and the About tab logs `social` and `donate`.
struct SettingsViewModelTests {

    // MARK: - Private Properties

    private let analytics = AnalyticsStub()

    // MARK: - Public Methods

    @Test
    func startsWithTheDefaultsAndTheLoginItemStatus() {
        let viewModel = makeViewModel(loginItem: LoginItemSpy(status: .enabled))

        #expect(viewModel.launchAtLogin)
        #expect(!viewModel.loginItemNeedsApproval)
        #expect(viewModel.showsMenuBarExtra)
        #expect(viewModel.showsSizeInMenuBar)
        #expect(viewModel.minimumTemporaryAgeInDays == 3)
        #expect(viewModel.sendsUsageStatistics)
    }

    @Test
    func readsTheSavedChoices() {
        let store = InMemoryPreferencesStore([
            PreferencesMigrator.showMenuBarExtraKey: .value(false),
            PreferencesMigrator.showSizeInMenuBarKey: .value(false),
            SettingsViewModel.usageStatisticsKey: .value(false),
        ])
        store.set(14, for: SettingsViewModel.minimumAgeKey)

        let viewModel = makeViewModel(store: store)

        #expect(!viewModel.showsMenuBarExtra)
        #expect(!viewModel.showsSizeInMenuBar)
        #expect(!viewModel.sendsUsageStatistics)
        #expect(viewModel.minimumTemporaryAgeInDays == 14)
    }

    /// Only 1, 3, 7 and 14 days are offered (D7); anything else falls back to 3.
    @Test
    func anUnknownMinimumAgeFallsBackToTheDefault() {
        let store = InMemoryPreferencesStore()
        store.set(5, for: SettingsViewModel.minimumAgeKey)

        #expect(SettingsViewModel.minimumAgeOptions == [1, 3, 7, 14])
        #expect(makeViewModel(store: store).minimumTemporaryAgeInDays == 3)
        #expect(SettingsViewModel.storedMinimumAge(in: store) == 3)
    }

    @Test
    func savesEveryChoice() {
        let store = InMemoryPreferencesStore()

        var reportedAges: [Int] = []

        let viewModel = SettingsViewModel(
            store: store,
            loginItem: LoginItemSpy(status: .notRegistered),
            analytics: analytics
        ) { reportedAges.append($0) }

        viewModel.setShowsMenuBarExtra(false)
        viewModel.setShowsSizeInMenuBar(false)
        viewModel.setSendsUsageStatistics(false)
        viewModel.setMinimumTemporaryAgeInDays(7)
        viewModel.setMinimumTemporaryAgeInDays(5)

        #expect(store.bool(for: PreferencesMigrator.showMenuBarExtraKey) == false)
        #expect(store.bool(for: PreferencesMigrator.showSizeInMenuBarKey) == false)
        #expect(store.bool(for: SettingsViewModel.usageStatisticsKey) == false)
        #expect(store.integer(for: SettingsViewModel.minimumAgeKey) == 7)
        #expect(viewModel.minimumTemporaryAgeInDays == 7)
        #expect(reportedAges == [7], "Only the offered values are accepted.")
        #expect(!viewModel.showsMenuBarExtra)
    }

    /// `SMAppService` is the source of truth (R15).
    @Test
    func turnsTheLoginItemOnAndOff() {
        let loginItem = LoginItemSpy(status: .notRegistered)
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.setLaunchAtLogin(true)

        #expect(viewModel.launchAtLogin)

        viewModel.setLaunchAtLogin(false)

        #expect(loginItem.requests == [true, false])
        #expect(!viewModel.launchAtLogin)
        #expect(viewModel.loginItemFailure == nil)
    }

    @Test
    func aFailingLoginItemKeepsTheRealStatusAndShowsTheFailure() {
        let viewModel = makeViewModel(loginItem: LoginItemSpy(status: .notRegistered, failure: .permissionDenied))

        viewModel.setLaunchAtLogin(true)

        #expect(!viewModel.launchAtLogin)
        #expect(viewModel.loginItemFailure == .permissionDenied)
    }

    /// macOS may ask the user to allow it in System Settings › General › Login Items. The switch
    /// stays on, so the item can still be turned off from here.
    @Test
    func aLoginItemWaitingForApprovalIsShown() {
        let viewModel = makeViewModel(loginItem: LoginItemSpy(status: .requiresApproval))

        #expect(viewModel.launchAtLogin)
        #expect(viewModel.loginItemNeedsApproval)
    }

    /// A register that ends waiting for approval shows only the guidance, not a failure too.
    @Test
    func aRegisterThatNeedsApprovalShowsOnlyTheGuidance() {
        let loginItem = LoginItemSpy(
            status: .notRegistered,
            failure: .unknown(domain: "SMAppServiceErrorDomain", code: 1),
            statusAfterFailure: .requiresApproval
        )
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.setLaunchAtLogin(true)

        #expect(viewModel.loginItemFailure == nil)
        #expect(viewModel.loginItemNeedsApproval)
    }

    @Test
    func theAboutTabLogsDonationsAndSocialLinks() {
        let viewModel = makeViewModel()

        viewModel.logDonation()
        viewModel.logSocial(.github)

        #expect(analytics.events.map(\.name) == ["donate", "social"])
        #expect(analytics.events.last?.properties["platform"] as? String == "github")
    }

    // MARK: - Private Methods

    private func makeViewModel(
        store: InMemoryPreferencesStore = InMemoryPreferencesStore(),
        loginItem: LoginItemSpy = LoginItemSpy(status: .notRegistered)
    ) -> SettingsViewModel {
        SettingsViewModel(store: store, loginItem: loginItem, analytics: analytics)
    }

}
