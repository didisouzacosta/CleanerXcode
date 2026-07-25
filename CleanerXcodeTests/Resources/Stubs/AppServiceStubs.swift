import Foundation

@testable import CleanerXcode

@MainActor
final class ExternalURLHandlerStub: ExternalURLHandling {

    private(set) var openedURLs = [URL]()

    func open(_ url: URL) {
        openedURLs.append(url)
    }

}

@MainActor
final class ApplicationControllerStub: ApplicationControlling {

    private(set) var didTerminate = false

    func terminate() {
        didTerminate = true
    }

}

@MainActor
final class LaunchAtLoginControllerStub: LaunchAtLoginControlling {

    var isEnabled = false

}

struct ApplicationInfoStub: ApplicationInfo {

    let version: String
    let build: String
    let fullVersion: String
    let remoteVersion: Version

    init(
        version: String = "1.0.0",
        build: String = "1",
        fullVersion: String = "1.0.0.1",
        remoteVersion: Version = Version(
            version: "1.1.0",
            build: "2",
            downloadURL: Constants.githubURL
        )
    ) {
        self.version = version
        self.build = build
        self.fullVersion = fullVersion
        self.remoteVersion = remoteVersion
    }

    func loadLatestVersionFromRemote() async throws -> Version {
        remoteVersion
    }

}
