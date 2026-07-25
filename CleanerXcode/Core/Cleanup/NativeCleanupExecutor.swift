import Foundation

struct CleanupActionResult: Equatable, Sendable {

    // MARK: - Public Properties

    let action: CleanupAction
    let targetResults: [CleanupTargetResult]

    var errors: [CleanupOperationError] {
        targetResults.compactMap(\.error)
    }
}

struct CleanupTargetResult: Equatable, Sendable {

    // MARK: - Public Properties

    let target: URL?
    let outcome: CleanupTargetOutcome

    var error: CleanupOperationError? {
        guard case .failed(let error) = outcome else {
            return nil
        }

        return error
    }

    var isSuccess: Bool {
        error == nil
    }
}

enum CleanupTargetOutcome: Equatable, Sendable {
    case removed
    case notFound
    case preferencesReset
    case failed(CleanupOperationError)
}

struct CleanupOperationError: Error, Equatable, LocalizedError, Sendable {

    // MARK: - Public Properties

    let action: CleanupAction
    let target: URL?
    let message: String

    var errorDescription: String? {
        message
    }
}

struct CleanupMeasurementError: Error, Equatable, LocalizedError, Sendable {

    // MARK: - Public Properties

    let target: URL
    let message: String

    var errorDescription: String? {
        message
    }
}

private enum XcodePreferencesDomain {
    static let xcode = "com.apple.dt.Xcode"
}

actor NativeCleanupExecutor {

    // MARK: - Private Properties

    private let paths: any CleanupPathProviding
    private let fileSystem: any CleanupFileSystem
    private let preferencesResetter: any XcodePreferencesResetting

    // MARK: - Initializer

    init(
        _ paths: any CleanupPathProviding = CleanupPaths(),
        fileSystem: any CleanupFileSystem = DescriptorAnchoredCleanupFileSystem(),
        preferencesResetter: any XcodePreferencesResetting = UserDefaultsXcodePreferencesResetter()
    ) {
        self.paths = paths
        self.fileSystem = fileSystem
        self.preferencesResetter = preferencesResetter
    }

    // MARK: - Public Methods

    func measureUsedSpace() throws -> UsedSpace {
        try UsedSpace(
            allocatedSize(at: paths.derivedData),
            archives: allocatedSize(at: paths.archives),
            simulatorData: allocatedSize(at: paths.simulatorData),
            xcodeCache: allocatedSize(at: paths.xcodeCache),
            carthageCache: allocatedSize(at: paths.carthageCache),
            cocoaPodsCache: allocatedSize(at: paths.cocoaPodsCache),
            deviceSupportIOS: allocatedSize(at: paths.deviceSupportIOS),
            deviceSupportWatchOS: allocatedSize(at: paths.deviceSupportWatchOS),
            deviceSupportTvOS: allocatedSize(at: paths.deviceSupportTvOS)
        )
    }

    func perform(_ action: CleanupAction) async -> CleanupActionResult {
        switch action {
        case .removeArchives:
            return CleanupActionResult(action: action, targetResults: remove([paths.archives], for: action))
        case .removeCaches:
            return CleanupActionResult(action: action, targetResults: remove([paths.xcodeCache, paths.carthageCache, paths.cocoaPodsCache], for: action))
        case .removeDerivedData:
            return CleanupActionResult(action: action, targetResults: remove([paths.derivedData], for: action))
        case .clearDeviceSupport:
            return CleanupActionResult(action: action, targetResults: remove([paths.deviceSupportIOS, paths.deviceSupportWatchOS, paths.deviceSupportTvOS], for: action))
        case .clearSimulatorData:
            return CleanupActionResult(action: action, targetResults: remove([paths.simulatorData], for: action))
        case .removeOldSimulators:
            let error = CleanupOperationError(
                action: action,
                target: nil,
                message: "Removing unavailable simulators requires simulator control."
            )
            return CleanupActionResult(action: action, targetResults: [.init(target: nil, outcome: .failed(error))])
        case .resetXcodePreferences:
            return await resetPreferences(for: action)
        }
    }

    // MARK: - Private Methods

    private func allocatedSize(at url: URL) throws -> Int64 {
        do {
            let context = try validatedContext(for: url)
            return try fileSystem.allocatedSize(of: context.secureTarget)
        } catch {
            throw CleanupMeasurementError(target: url, message: error.localizedDescription)
        }
    }

    private func remove(_ urls: [URL], for action: CleanupAction) -> [CleanupTargetResult] {
        urls.map { url in
            do {
                let context = try validatedContext(for: url)
                try fileSystem.remove(target: context.secureTarget)
                return CleanupTargetResult(target: url, outcome: .removed)
            } catch {
                if fileSystem.isFileNotFound(error) {
                    return CleanupTargetResult(target: url, outcome: .notFound)
                }

                return CleanupTargetResult(
                    target: url,
                    outcome: .failed(.init(action: action, target: url, message: error.localizedDescription))
                )
            }
        }
    }

    private func resetPreferences(for action: CleanupAction) async -> CleanupActionResult {
        do {
            try await preferencesResetter.reset(XcodePreferencesDomain.xcode)
            return .init(action: action, targetResults: [.init(target: nil, outcome: .preferencesReset)])
        } catch {
            let operationError = CleanupOperationError(action: action, target: nil, message: error.localizedDescription)
            return .init(action: action, targetResults: [.init(target: nil, outcome: .failed(operationError))])
        }
    }

    private func validatedContext(for target: URL) throws -> ValidatedTargetContext {
        let rootComponents = try lexicalComponents(for: paths.cleanupRoot)
        let targetComponents = try lexicalComponents(for: target)

        guard targetComponents.count > rootComponents.count, targetComponents.starts(with: rootComponents) else {
            throw CleanupPathSafetyError.untrustedTarget(target)
        }

        return try .init(paths.cleanupRoot, targetComponents: Array(targetComponents[rootComponents.count...]))
    }

    private func lexicalComponents(for url: URL) throws -> [String] {
        guard url.isFileURL else {
            throw CleanupPathSafetyError.nonFileURL(url)
        }

        guard url.path.hasPrefix("/") else {
            throw CleanupPathSafetyError.relativePath(url)
        }

        var normalizedComponents = ["/"]

        for component in url.pathComponents.dropFirst() {
            guard component != ".." else {
                throw CleanupPathSafetyError.parentTraversal(url)
            }

            if component != "." {
                normalizedComponents.append(component)
            }
        }

        return normalizedComponents
    }
}

private enum CleanupPathSafetyError: LocalizedError {
    case untrustedTarget(URL)
    case parentTraversal(URL)
    case nonFileURL(URL)
    case relativePath(URL)

    var errorDescription: String? {
        switch self {
        case .untrustedTarget(let url):
            "Cleanup target is outside the trusted root: \(url.path)"
        case .parentTraversal(let url):
            "Cleanup target contains a parent traversal: \(url.path)"
        case .nonFileURL(let url):
            "Cleanup target is not a file URL: \(url.absoluteString)"
        case .relativePath(let url):
            "Cleanup target is not an absolute path: \(url.path)"
        }
    }
}

private struct ValidatedTargetContext {

    // MARK: - Private Properties

    let secureTarget: CleanupSecureTarget

    // MARK: - Initializer

    init(_ rootURL: URL, targetComponents: [String]) throws {
        secureTarget = try .init(rootURL, relativeComponents: targetComponents)
    }
}
