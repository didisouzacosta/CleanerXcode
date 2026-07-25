import Foundation

@MainActor
final class AppContainer {

    // MARK: - Public Properties

    let router: AppRouter
    let cleanerViewModel: CleanerViewModel
    let preferencesViewModel: PreferencesViewModel
    let menuBarViewModel: MenuBarViewModel

    // MARK: - Private Properties

    private let analytics: Analytics
    private let cleanerStore: CleanerStore
    private let preferences: Preferences
    private let updateStore: UpdateStore

    // MARK: - Initializer

    init(
        commandExecutor: CommandExecutor = Shell(),
        applicationInfo: ApplicationInfo = Bundle.main,
        userDefaults: UserDefaults = .standard,
        analytics: Analytics = GoogleAnalytics(),
        urlHandler: ExternalURLHandling = WorkspaceURLHandler(),
        applicationController: ApplicationControlling = ApplicationController(),
        launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController()
    ) {
        let preferences = Preferences(userDefaults)
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
        )
        let router = AppRouter()
        let updateStore = UpdateStore(applicationInfo)

        self.analytics = analytics
        self.cleanerStore = cleanerStore
        self.preferences = preferences
        self.router = router
        self.updateStore = updateStore
        cleanerViewModel = CleanerViewModel(
            cleanerStore: cleanerStore,
            updateStore: updateStore,
            analytics: analytics,
            router: router,
            urlHandler: urlHandler,
            applicationController: applicationController
        )
        preferencesViewModel = PreferencesViewModel(
            cleanerStore: cleanerStore,
            preferences: preferences,
            analytics: analytics,
            router: router,
            urlHandler: urlHandler,
            launchAtLoginController: launchAtLoginController
        )
        menuBarViewModel = MenuBarViewModel(
            cleanerStore: cleanerStore,
            preferences: preferences,
            updateStore: updateStore,
            launchAtLoginController: launchAtLoginController
        )
    }

}
