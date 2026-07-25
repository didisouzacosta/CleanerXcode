import Observation

@MainActor
@Observable
final class PreferencesViewModel {

    // MARK: - Public Properties

    var removeArchives: Bool {
        get { preferences.removeArchives.value }
        set { preferences.removeArchives.value = newValue }
    }

    var removeCaches: Bool {
        get { preferences.removeCaches.value }
        set { preferences.removeCaches.value = newValue }
    }

    var removeDerivedData: Bool {
        get { preferences.removeDerivedData.value }
        set { preferences.removeDerivedData.value = newValue }
    }

    var clearDeviceSupport: Bool {
        get { preferences.clearDeviceSupport.value }
        set { preferences.clearDeviceSupport.value = newValue }
    }

    var clearSimulatorData: Bool {
        get { preferences.clearSimulatorData.value }
        set { preferences.clearSimulatorData.value = newValue }
    }

    var removeOldSimulators: Bool {
        get { preferences.removeOldSimulators.value }
        set { preferences.removeOldSimulators.value = newValue }
    }

    var resetXcodePreferences: Bool {
        get { preferences.resetXcodePreferences.value }
        set { preferences.resetXcodePreferences.value = newValue }
    }

    var displayFreeUpSpaceInMenuBar: Bool {
        get { preferences.displayFreeUpSpaceInMenuBar.value }
        set { preferences.displayFreeUpSpaceInMenuBar.value = newValue }
    }

    var launchAtLogin: Bool {
        get { preferences.launchAtLogin.value }
        set {
            preferences.launchAtLogin.value = newValue
            launchAtLoginController.isEnabled = newValue
        }
    }

    var archivesDetail: String {
        cleanerStore.usedSpace.value.archives.byteFormatted()
    }

    var cachesDetail: String {
        cleanerStore.usedSpace.value.cache.byteFormatted()
    }

    var derivedDataDetail: String {
        cleanerStore.usedSpace.value.derivedData.byteFormatted()
    }

    var deviceSupportDetail: String {
        cleanerStore.usedSpace.value.deviceSupport.byteFormatted()
    }

    var simulatorDataDetail: String {
        cleanerStore.usedSpace.value.simulatorData.byteFormatted()
    }

    // MARK: - Private Properties

    private let analytics: Analytics
    private let cleanerStore: CleanerStore
    private var launchAtLoginController: LaunchAtLoginControlling
    private let preferences: Preferences
    private let router: AppRouting
    private let urlHandler: ExternalURLHandling

    // MARK: - Initializer

    init(
        cleanerStore: CleanerStore,
        preferences: Preferences,
        analytics: Analytics,
        router: AppRouting,
        urlHandler: ExternalURLHandling,
        launchAtLoginController: LaunchAtLoginControlling
    ) {
        self.cleanerStore = cleanerStore
        self.preferences = preferences
        self.analytics = analytics
        self.router = router
        self.urlHandler = urlHandler
        self.launchAtLoginController = launchAtLoginController
    }

    // MARK: - Public Methods

    func showCleaner() {
        router.showCleaner()
    }

    func donate() {
        urlHandler.open(Constants.donateURL)
        analytics.log(.donate)
    }

}
