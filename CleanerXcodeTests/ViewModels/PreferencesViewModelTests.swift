import Foundation
import Testing

@testable import CleanerXcode

@MainActor
@Suite(.serialized)
struct PreferencesViewModelTests {

    @Test
    func updatesPreferencesAndLaunchAtLogin() {
        let dependencies = makeDependencies()

        dependencies.viewModel.removeArchives = false
        dependencies.viewModel.launchAtLogin = false

        #expect(!dependencies.preferences.removeArchives.value)
        #expect(!dependencies.preferences.launchAtLogin.value)
        #expect(!dependencies.launchAtLoginController.isEnabled)
    }

    @Test
    func coordinatesNavigationAndDonation() {
        let dependencies = makeDependencies()

        dependencies.router.showPreferences()
        dependencies.viewModel.showCleaner()
        dependencies.viewModel.donate()

        #expect(dependencies.router.path == .cleaner)
        #expect(dependencies.urlHandler.openedURLs == [Constants.donateURL])
        #expect(dependencies.analytics.event?.name == "donate")
    }

    // MARK: - Private Methods

    private func makeDependencies() -> PreferencesDependencies {
        let commandExecutor = CommandExecutorStub()
        commandExecutor.result = "{}"

        let analytics = AnalyticsStub()
        let userDefaults = UserDefaults(suiteName: "PreferencesViewModelTests")!
        userDefaults.removePersistentDomain(forName: "PreferencesViewModelTests")
        let preferences = Preferences(userDefaults)
        let router = AppRouter()
        let store = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
        )
        let urlHandler = ExternalURLHandlerStub()
        let launchAtLoginController = LaunchAtLoginControllerStub()
        let viewModel = PreferencesViewModel(
            cleanerStore: store,
            preferences: preferences,
            analytics: analytics,
            router: router,
            urlHandler: urlHandler,
            launchAtLoginController: launchAtLoginController
        )

        return PreferencesDependencies(
            analytics: analytics,
            launchAtLoginController: launchAtLoginController,
            preferences: preferences,
            router: router,
            urlHandler: urlHandler,
            viewModel: viewModel
        )
    }

}

@MainActor
private struct PreferencesDependencies {

    let analytics: AnalyticsStub
    let launchAtLoginController: LaunchAtLoginControllerStub
    let preferences: Preferences
    let router: AppRouter
    let urlHandler: ExternalURLHandlerStub
    let viewModel: PreferencesViewModel

}
