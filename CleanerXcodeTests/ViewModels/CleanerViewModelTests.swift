import Foundation
import Testing

@testable import CleanerXcode

@MainActor
@Suite(.serialized)
struct CleanerViewModelTests {

    @Test
    func coordinatesNavigationSocialURLsAndTermination() {
        let dependencies = makeDependencies()

        dependencies.viewModel.openPreferences()
        dependencies.viewModel.openSocial(.github)
        dependencies.viewModel.quit()

        #expect(dependencies.router.path == .preferences)
        #expect(dependencies.urlHandler.openedURLs == [Constants.githubURL])
        #expect(dependencies.analytics.event?.name == "social")
        #expect(dependencies.applicationController.didTerminate)
    }

    @Test
    func exposesCleanerActionState() async throws {
        let dependencies = makeDependencies()

        try await waitUntil {
            !dependencies.store.usedSpace.isLoading
        }

        #expect(
            dependencies.viewModel.buttonState.title
                == "Clear \(dependencies.store.freeUpSpace.byteFormatter())"
        )
        #expect(dependencies.viewModel.buttonState.isEnabled)
        #expect(!dependencies.viewModel.buttonState.showsProgress)
    }

    // MARK: - Private Methods

    private func makeDependencies() -> Dependencies {
        let commandExecutor = CommandExecutorStub()
        commandExecutor.result = """
        {
          "derived_data": 4510292,
          "archives": 0,
          "simulator_data": 17564480,
          "xcode_cache": 1116,
          "carthage_cache": 0,
          "device_support_ios": 4595184,
          "device_support_watchos": 0,
          "device_support_tvos": 0
        }
        """

        let analytics = AnalyticsStub()
        let userDefaults = UserDefaults(suiteName: "CleanerViewModelTests")!
        userDefaults.removePersistentDomain(forName: "CleanerViewModelTests")
        let preferences = Preferences(userDefaults)
        let router = AppRouter()
        let store = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
        )
        let urlHandler = ExternalURLHandlerStub()
        let applicationController = ApplicationControllerStub()
        let viewModel = CleanerViewModel(
            cleanerStore: store,
            updateStore: UpdateStore(ApplicationInfoStub()),
            analytics: analytics,
            router: router,
            urlHandler: urlHandler,
            applicationController: applicationController
        )

        return Dependencies(
            analytics: analytics,
            applicationController: applicationController,
            router: router,
            store: store,
            urlHandler: urlHandler,
            viewModel: viewModel
        )
    }

}

@MainActor
private struct Dependencies {

    let analytics: AnalyticsStub
    let applicationController: ApplicationControllerStub
    let router: AppRouter
    let store: CleanerStore
    let urlHandler: ExternalURLHandlerStub
    let viewModel: CleanerViewModel

}
