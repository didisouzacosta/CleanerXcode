import Observation
import SwiftUI

@MainActor
@Observable
final class CleanerViewModel {

    // MARK: - Public Properties

    var buttonState: CleanerButtonState {
        CleanerButtonState(
            title: cleanerButtonTitle,
            tint: cleanerButtonTint,
            progress: cleanerStore.progress,
            total: cleanerStore.total,
            showsProgress: cleanerStore.status == .isCleaning,
            isEnabled: cleanerStore.status != .isCleaning && cleanerStore.status != .isCompleted
        )
    }

    var isPreferencesEnabled: Bool {
        cleanerStore.status != .isCleaning
    }

    var updateTitle: String? {
        updateStore.hasUpdate.value ? "Update" : nil
    }

    var versionTitle: String {
        "Version \(Bundle.main.fullVersion)"
    }

    // MARK: - Private Properties

    private let analytics: Analytics
    private let applicationController: ApplicationControlling
    private let cleanerStore: CleanerStore
    private let router: AppRouting
    private let updateStore: UpdateStore
    private let urlHandler: ExternalURLHandling

    private var cleanerButtonTitle: String {
        switch cleanerStore.status {
        case .isCleaning:
            "Cleaning"
        case .error:
            "Try again"
        case .isCompleted:
            "🎉 Success, all clear!"
        case .idle:
            cleanerStore.freeUpSpace.isZero
                ? "Clear"
                : "Clear \(cleanerStore.freeUpSpace.byteFormatter())"
        }
    }

    private var cleanerButtonTint: Color {
        switch cleanerStore.status {
        case .idle:
            .blue
        case .isCompleted, .isCleaning:
            .greenAction
        case .error:
            .red
        }
    }

    // MARK: - Initializer

    init(
        cleanerStore: CleanerStore,
        updateStore: UpdateStore,
        analytics: Analytics,
        router: AppRouting,
        urlHandler: ExternalURLHandling,
        applicationController: ApplicationControlling
    ) {
        self.cleanerStore = cleanerStore
        self.updateStore = updateStore
        self.analytics = analytics
        self.router = router
        self.urlHandler = urlHandler
        self.applicationController = applicationController
    }

    // MARK: - Public Methods

    func clean() {
        cleanerStore.clear()
    }

    func openPreferences() {
        router.showPreferences()
    }

    func openSocial(_ social: AnalyticsEvent.Social) {
        urlHandler.open(social.url)
        analytics.log(.social(social))
    }

    func openUpdate() {
        guard let url = updateStore.version?.downloadURL else { return }

        urlHandler.open(url)
    }

    func quit() {
        applicationController.terminate()
    }

}

struct CleanerButtonState: Equatable {

    let title: String
    let tint: Color
    let progress: Double
    let total: Double
    let showsProgress: Bool
    let isEnabled: Bool

}

private extension AnalyticsEvent.Social {

    var url: URL {
        switch self {
        case .github:
            Constants.githubURL
        case .x:
            Constants.xURL
        case .linkedin:
            Constants.linkedinURL
        }
    }

}
