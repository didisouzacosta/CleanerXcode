import Observation

@MainActor
@Observable
final class MenuBarViewModel {

    // MARK: - Public Properties

    var statusTitle: String? {
        guard preferences.displayFreeUpSpaceInMenuBar.value else { return nil }

        if cleanerStore.status == .isCleaning {
            return "Cleaning"
        }

        if cleanerStore.isCalculating {
            return "Calculating"
        }

        return cleanerStore.freeUpSpace.byteFormatter()
    }

    // MARK: - Private Properties

    private let cleanerStore: CleanerStore
    private var launchAtLoginController: LaunchAtLoginControlling
    private let preferences: Preferences
    private let updateStore: UpdateStore
    private var didStart = false

    // MARK: - Initializer

    init(
        cleanerStore: CleanerStore,
        preferences: Preferences,
        updateStore: UpdateStore,
        launchAtLoginController: LaunchAtLoginControlling
    ) {
        self.cleanerStore = cleanerStore
        self.preferences = preferences
        self.updateStore = updateStore
        self.launchAtLoginController = launchAtLoginController
    }

    // MARK: - Public Methods

    func start() {
        guard !didStart else { return }

        didStart = true
        launchAtLoginController.isEnabled = preferences.launchAtLogin.value
        updateStore.checkUpdates()
    }

}
