import Foundation

protocol CleanupPathProviding: Sendable {

    var cleanupRoot: URL { get }
    var derivedData: URL { get }
    var archives: URL { get }
    var simulatorData: URL { get }
    var xcodeCache: URL { get }
    var carthageCache: URL { get }
    var cocoaPodsCache: URL { get }
    var deviceSupportIOS: URL { get }
    var deviceSupportWatchOS: URL { get }
    var deviceSupportTvOS: URL { get }
}

enum CleanupPathRoot: Sendable {
    case homeDirectory
    case libraryDirectory
}

struct CleanupPaths: CleanupPathProviding, Sendable {

    // MARK: - Public Properties

    let cleanupRoot: URL
    let derivedData: URL
    let archives: URL
    let simulatorData: URL
    let xcodeCache: URL
    let carthageCache: URL
    let cocoaPodsCache: URL
    let deviceSupportIOS: URL
    let deviceSupportWatchOS: URL
    let deviceSupportTvOS: URL

    // MARK: - Initializer

    init(
        _ directory: URL = FileManager.default.homeDirectoryForCurrentUser,
        root: CleanupPathRoot = .homeDirectory
    ) {
        let cleanupRoot = switch root {
        case .homeDirectory:
            directory.appending(path: "Library", directoryHint: .isDirectory)
        case .libraryDirectory:
            directory
        }
        let developerDirectory = cleanupRoot.appending(path: "Developer", directoryHint: .isDirectory)
        let xcodeDirectory = developerDirectory.appending(path: "Xcode", directoryHint: .isDirectory)
        let cacheDirectory = cleanupRoot.appending(path: "Caches", directoryHint: .isDirectory)

        self.cleanupRoot = cleanupRoot
        derivedData = xcodeDirectory.appending(path: "DerivedData", directoryHint: .isDirectory)
        archives = xcodeDirectory.appending(path: "Archives", directoryHint: .isDirectory)
        simulatorData = developerDirectory.appending(path: "CoreSimulator", directoryHint: .isDirectory)
        xcodeCache = cacheDirectory.appending(path: "com.apple.dt.Xcode", directoryHint: .isDirectory)
        carthageCache = cacheDirectory.appending(path: "org.carthage.CarthageKit", directoryHint: .isDirectory)
        cocoaPodsCache = cacheDirectory.appending(path: "CocoaPods/Pods", directoryHint: .isDirectory)
        deviceSupportIOS = xcodeDirectory.appending(path: "iOS DeviceSupport", directoryHint: .isDirectory)
        deviceSupportWatchOS = xcodeDirectory.appending(path: "watchOS DeviceSupport", directoryHint: .isDirectory)
        deviceSupportTvOS = xcodeDirectory.appending(path: "tvOS DeviceSupport", directoryHint: .isDirectory)
    }
}
