import Firebase
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !DEBUG
        FirebaseApp.configure()
        #endif
    }

}

@main
struct CleanerXcodeApp: App {

    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // MARK: - States

    @State private var container: AppContainer

    // MARK: - Body

    var body: some Scene {
        MenuBarExtra {
            AppRootView(
                container.router,
                cleanerViewModel: container.cleanerViewModel,
                preferencesViewModel: container.preferencesViewModel
            )
            .frame(width: 340)
        } label: {
            MenuBarLabel(container.menuBarViewModel)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Initializer

    init() {
        _container = State(initialValue: AppContainer())
    }

}

private struct MenuBarLabel: View {

    // MARK: - Private Properties

    private let viewModel: MenuBarViewModel

    // MARK: - Body

    var body: some View {
        HStack {
            Image("iconClear")

            if let statusTitle = viewModel.statusTitle {
                Text(statusTitle)
            }
        }
        .onAppear(perform: viewModel.start)
    }

    // MARK: - Initializer

    init(_ viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
    }

}
