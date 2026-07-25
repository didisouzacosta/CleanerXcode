import Foundation

@MainActor
enum PreviewFactory {

    static func container() -> AppContainer {
        AppContainer(
            commandExecutor: PreviewCommandExecutor(),
            applicationInfo: PreviewApplicationInfo(),
            userDefaults: UserDefaults(suiteName: "CleanerXcode.Previews") ?? .standard,
            analytics: PreviewAnalytics(),
            urlHandler: PreviewURLHandler(),
            applicationController: PreviewApplicationController(),
            launchAtLoginController: PreviewLaunchAtLoginController()
        )
    }

}

private struct PreviewCommandExecutor: CommandExecutor {

    let isCancelled = false

    func run(_ command: Command) async throws -> String? {
        guard command == .calculateFreeUpSpace else { return nil }

        return """
        {
          "archives": 1200000000,
          "cache": 430000000,
          "derivedData": 2400000000,
          "deviceSupport": 800000000,
          "simulatorData": 1600000000,
          "totalSize": 6430000000
        }
        """
    }

    func cancel() {}

}

private struct PreviewApplicationInfo: ApplicationInfo {

    let version = "1.0.0"
    let build = "1"
    let fullVersion = "1.0.0.1"

    func loadLatestVersionFromRemote() async throws -> Version {
        Version(
            version: "1.1.0",
            build: "2",
            downloadURL: Constants.githubURL
        )
    }

}

private struct PreviewAnalytics: @MainActor Analytics {

    func log(_ event: AnalyticsEvent) {}

}

@MainActor
private struct PreviewURLHandler: ExternalURLHandling {

    func open(_ url: URL) {}

}

@MainActor
private struct PreviewApplicationController: ApplicationControlling {

    func terminate() {}

}

@MainActor
private final class PreviewLaunchAtLoginController: LaunchAtLoginControlling {

    var isEnabled = false

}
