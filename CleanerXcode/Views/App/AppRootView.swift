import SwiftUI

struct AppRootView: View {

    // MARK: - Private Properties

    private let cleanerViewModel: CleanerViewModel
    private let preferencesViewModel: PreferencesViewModel
    private let router: AppRouter

    private var cleanerOpacity: Double {
        router.path == .cleaner ? 1 : 0
    }

    private var preferencesOpacity: Double {
        router.path == .preferences ? 1 : 0
    }

    private var contentHeight: CGFloat {
        router.path == .cleaner ? 330 : 540
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            CleanerView(cleanerViewModel)
                .opacity(cleanerOpacity)
                .allowsHitTesting(router.path == .cleaner)
                .accessibilityHidden(router.path != .cleaner)

            PreferencesView(preferencesViewModel)
                .opacity(preferencesOpacity)
                .allowsHitTesting(router.path == .preferences)
                .accessibilityHidden(router.path != .preferences)
        }
        .frame(height: contentHeight)
        .animation(.smooth, value: router.path)
    }

    // MARK: - Initializer

    init(
        _ router: AppRouter,
        cleanerViewModel: CleanerViewModel,
        preferencesViewModel: PreferencesViewModel
    ) {
        self.router = router
        self.cleanerViewModel = cleanerViewModel
        self.preferencesViewModel = preferencesViewModel
    }

}

#Preview {
    let container = PreviewFactory.container()

    AppRootView(
        container.router,
        cleanerViewModel: container.cleanerViewModel,
        preferencesViewModel: container.preferencesViewModel
    )
    .frame(width: 340)
}
