import AppKit
import LaunchAtLogin

@MainActor
protocol ExternalURLHandling {

    func open(_ url: URL)

}

@MainActor
protocol ApplicationControlling {

    func terminate()

}

@MainActor
protocol LaunchAtLoginControlling {

    var isEnabled: Bool { get set }

}

@MainActor
struct WorkspaceURLHandler: ExternalURLHandling {

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

}

@MainActor
struct ApplicationController: ApplicationControlling {

    func terminate() {
        NSApplication.shared.terminate(nil)
    }

}

@MainActor
final class LaunchAtLoginController: LaunchAtLoginControlling {

    // MARK: - Public Properties

    var isEnabled: Bool {
        get {
            LaunchAtLogin.isEnabled
        }
        set {
            LaunchAtLogin.isEnabled = newValue
        }
    }

}
