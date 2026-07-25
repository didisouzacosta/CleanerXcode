import Foundation
import Testing

@testable import CleanerXcode

struct NativeCleanupExecutorTests {

    // MARK: - Public Methods

    @Test
    func preservesPersistedCleanupActionIdentifiers() {
        #expect(CleanupAction.removeArchives.id == "remove-archives")
        #expect(CleanupAction.removeCaches.id == "remove-caches")
        #expect(CleanupAction.removeDerivedData.id == "remove-derived-data")
        #expect(CleanupAction.clearDeviceSupport.id == "clear-device-support")
        #expect(CleanupAction.clearSimulatorData.id == "clear-simulator-data")
        #expect(CleanupAction.removeOldSimulators.id == "remove-old-simulators")
        #expect(CleanupAction.resetXcodePreferences.id == "reset-xcode-preferences")
    }

    @Test
    func createsTheExactCleanupPathsFromAHomeDirectory() {
        let homeDirectory = URL(filePath: "/temporary/home", directoryHint: .isDirectory)
        let paths = CleanupPaths(homeDirectory)

        #expect(paths.derivedData.path == "/temporary/home/Library/Developer/Xcode/DerivedData")
        #expect(paths.archives.path == "/temporary/home/Library/Developer/Xcode/Archives")
        #expect(paths.simulatorData.path == "/temporary/home/Library/Developer/CoreSimulator")
        #expect(paths.xcodeCache.path == "/temporary/home/Library/Caches/com.apple.dt.Xcode")
        #expect(paths.carthageCache.path == "/temporary/home/Library/Caches/org.carthage.CarthageKit")
        #expect(paths.cocoaPodsCache.path == "/temporary/home/Library/Caches/CocoaPods/Pods")
        #expect(paths.deviceSupportIOS.path == "/temporary/home/Library/Developer/Xcode/iOS DeviceSupport")
        #expect(paths.deviceSupportWatchOS.path == "/temporary/home/Library/Developer/Xcode/watchOS DeviceSupport")
        #expect(paths.deviceSupportTvOS.path == "/temporary/home/Library/Developer/Xcode/tvOS DeviceSupport")
    }

    @Test
    func measuresAllocatedSpaceAndIgnoresSymbolicLinkTargets() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        try fixture.write(Data(repeating: 1, count: 4_096), to: fixture.paths.derivedData.appending(path: "local.data"))
        try fixture.write(Data(repeating: 1, count: 1_048_576), to: fixture.externalDirectory.appending(path: "external.data"))
        try FileManager.default.createSymbolicLink(
            at: fixture.paths.derivedData.appending(path: "external-link"),
            withDestinationURL: fixture.externalDirectory
        )

        let executor = NativeCleanupExecutor(fixture.paths)
        let space = try await executor.measureUsedSpace()

        #expect(space.derivedData > 0)
        #expect(space.derivedData < 1_048_576)
        #expect(space.cocoaPodsCache == 0)
    }

    @Test
    func measuresEveryConfiguredDirectoryInBytes() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let measuredPaths = [
            fixture.paths.derivedData,
            fixture.paths.archives,
            fixture.paths.simulatorData,
            fixture.paths.xcodeCache,
            fixture.paths.carthageCache,
            fixture.paths.cocoaPodsCache,
            fixture.paths.deviceSupportIOS,
            fixture.paths.deviceSupportWatchOS,
            fixture.paths.deviceSupportTvOS
        ]

        for path in measuredPaths {
            try fixture.write(Data(repeating: 1, count: 4_096), to: path.appending(path: "content.data"))
        }

        let space = try await NativeCleanupExecutor(fixture.paths).measureUsedSpace()

        #expect(space.derivedData > 0)
        #expect(space.archives > 0)
        #expect(space.simulatorData > 0)
        #expect(space.xcodeCache > 0)
        #expect(space.carthageCache > 0)
        #expect(space.cocoaPodsCache > 0)
        #expect(space.deviceSupportIOS > 0)
        #expect(space.deviceSupportWatchOS > 0)
        #expect(space.deviceSupportTvOS > 0)
    }

    @Test
    func removesEveryCacheTargetAndTreatsMissingDirectoriesAsSuccess() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        try fixture.write(Data([1]), to: fixture.paths.xcodeCache.appending(path: "xcode.data"))
        try fixture.write(Data([1]), to: fixture.paths.carthageCache.appending(path: "carthage.data"))
        try fixture.write(Data([1]), to: fixture.paths.cocoaPodsCache.appending(path: "pods.data"))

        let executor = NativeCleanupExecutor(fixture.paths)
        let result = await executor.perform(.removeCaches)

        #expect(result.action == .removeCaches)
        #expect(result.errors.isEmpty)
        #expect(result.targetResults.count == 3)
        #expect(!FileManager.default.fileExists(atPath: fixture.paths.xcodeCache.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.paths.carthageCache.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.paths.cocoaPodsCache.path))
    }

    @Test
    func removesEachSingleDirectoryActionWithoutTouchingSymbolicLinkDestinations() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let actionTargets: [(CleanupAction, URL)] = [
            (.removeArchives, fixture.paths.archives),
            (.removeDerivedData, fixture.paths.derivedData),
            (.clearSimulatorData, fixture.paths.simulatorData)
        ]

        for (action, target) in actionTargets {
            try fixture.write(Data([1]), to: target.appending(path: "content.data"))
            let externalFile = fixture.externalDirectory.appending(path: "\(action.id).data")
            try fixture.write(Data([1]), to: externalFile)
            try FileManager.default.createSymbolicLink(
                at: target.appending(path: "external-link"),
                withDestinationURL: externalFile
            )

            let result = await NativeCleanupExecutor(fixture.paths).perform(action)

            #expect(result.errors.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: target.path))
            #expect(FileManager.default.fileExists(atPath: externalFile.path))
        }
    }

    @Test
    func treatsEveryMissingTargetAsAnIdempotentSuccess() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let result = await NativeCleanupExecutor(fixture.paths).perform(.clearDeviceSupport)

        #expect(result.errors.isEmpty)
        #expect(result.targetResults.count == 3)
        #expect(result.targetResults.map(\.outcome) == [.notFound, .notFound, .notFound])
    }

    @Test
    func aggregatesFilesystemFailuresWithoutSkippingIndependentTargets() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        try fixture.write(Data([1]), to: fixture.paths.deviceSupportIOS.appending(path: "ios.data"))
        try fixture.write(Data([1]), to: fixture.paths.deviceSupportWatchOS.appending(path: "watch.data"))
        try fixture.write(Data([1]), to: fixture.paths.deviceSupportTvOS.appending(path: "tv.data"))
        let fileSystem = FailingFileSystem(fixture.paths.deviceSupportWatchOS)
        let executor = NativeCleanupExecutor(fixture.paths, fileSystem: fileSystem)

        let result = await executor.perform(.clearDeviceSupport)

        #expect(result.errors.count == 1)
        #expect(result.targetResults.count == 3)
        #expect(!FileManager.default.fileExists(atPath: fixture.paths.deviceSupportIOS.path))
        #expect(FileManager.default.fileExists(atPath: fixture.paths.deviceSupportWatchOS.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.paths.deviceSupportTvOS.path))
    }

    @Test
    func resetsXcodePreferencesThroughInjectedResetter() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let resetter = PreferencesResetterSpy()
        let executor = NativeCleanupExecutor(fixture.paths, preferencesResetter: resetter)

        let result = await executor.perform(.resetXcodePreferences)

        #expect(result.errors.isEmpty)
        #expect(await resetter.resetCount == 1)
    }

    @Test
    func reportsSimulatorRemovalAsUnavailableUntilSimulatorControlIsConfigured() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let result = await NativeCleanupExecutor(fixture.paths).perform(.removeOldSimulators)

        #expect(result.errors.count == 1)
        #expect(result.errors.first?.action == .removeOldSimulators)
    }

    @Test
    func refusesToMeasureOrRemoveThroughAnAncestorSymbolicLink() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let externalDeveloperDirectory = fixture.externalDirectory.appending(path: "Developer", directoryHint: .isDirectory)
        let externalDerivedData = externalDeveloperDirectory.appending(path: "Xcode/DerivedData", directoryHint: .isDirectory)
        let externalFile = externalDerivedData.appending(path: "outside.data")
        try fixture.write(Data(repeating: 1, count: 4_096), to: externalFile)
        try FileManager.default.createDirectory(at: fixture.libraryRoot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: fixture.libraryRoot.appending(path: "Developer"),
            withDestinationURL: externalDeveloperDirectory
        )

        let executor = NativeCleanupExecutor(fixture.paths)

        await #expect(throws: CleanupMeasurementError.self) {
            try await executor.measureUsedSpace()
        }

        let result = await executor.perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: externalFile.path))
    }

    @Test
    func treatsANotFoundErrorDuringRemovalAsAnIdempotentSuccess() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let executor = NativeCleanupExecutor(
            fixture.paths,
            fileSystem: RemovalRaceFileSystem(fixture.paths.archives)
        )

        let result = await executor.perform(.removeArchives)

        #expect(result.errors.isEmpty)
        #expect(result.targetResults.map(\.outcome) == [.notFound])
    }

    @Test
    func resetsTheExactXcodePreferencesDomainThroughTheInjectedAbstraction() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let resetter = PreferencesResetterSpy()
        let executor = NativeCleanupExecutor(fixture.paths, preferencesResetter: resetter)

        _ = await executor.perform(.resetXcodePreferences)

        #expect(await resetter.domains == ["com.apple.dt.Xcode"])
    }

    @Test
    func rejectsAParentTraversalBeforeItCanReachAnExternalMarker() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let marker = fixture.externalDirectory.appending(path: "marker.data")
        let escapedTarget = URL(filePath: "\(fixture.libraryRoot.path)/../external", directoryHint: .isDirectory)
        try fixture.write(Data([1]), to: marker)
        let paths = OverriddenCleanupPaths(fixture.libraryRoot, derivedData: escapedTarget)
        let executor = NativeCleanupExecutor(paths)

        await #expect(throws: CleanupMeasurementError.self) {
            try await executor.measureUsedSpace()
        }

        let result = await executor.perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test
    func rejectsACleanupTargetThatEqualsTheTrustedRoot() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let marker = fixture.libraryRoot.appending(path: "marker.data")
        try fixture.write(Data([1]), to: marker)
        let paths = OverriddenCleanupPaths(fixture.libraryRoot, derivedData: fixture.libraryRoot)
        let result = await NativeCleanupExecutor(paths).perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test
    func rejectsARootPrefixCollisionBeforeItCanReachAnExternalMarker() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let collidingDirectory = fixture.rootDirectory.appending(path: "library2", directoryHint: .isDirectory)
        let marker = collidingDirectory.appending(path: "marker.data")
        try fixture.write(Data([1]), to: marker)
        let paths = OverriddenCleanupPaths(fixture.libraryRoot, derivedData: collidingDirectory)
        let result = await NativeCleanupExecutor(paths).perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test
    func rejectsASymbolicLinkTrustedRootBeforeItCanReachAnExternalMarker() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let externalLibrary = fixture.externalDirectory.appending(path: "library", directoryHint: .isDirectory)
        let marker = externalLibrary.appending(path: "Developer/Xcode/DerivedData/marker.data")
        let linkedLibrary = fixture.rootDirectory.appending(path: "linked-library", directoryHint: .isDirectory)
        try fixture.write(Data([1]), to: marker)
        try FileManager.default.createSymbolicLink(at: linkedLibrary, withDestinationURL: externalLibrary)
        let paths = CleanupPaths(linkedLibrary, root: .libraryDirectory)
        let executor = NativeCleanupExecutor(paths)

        await #expect(throws: CleanupMeasurementError.self) {
            try await executor.measureUsedSpace()
        }

        let result = await executor.perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test
    func rejectsANonFileTargetBeforeItCanReachAnExternalMarker() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let marker = fixture.externalDirectory.appending(path: "marker.data")
        try fixture.write(Data([1]), to: marker)
        let remoteTarget = try #require(URL(string: "https://example.invalid/DerivedData"))
        let paths = OverriddenCleanupPaths(fixture.libraryRoot, derivedData: remoteTarget)
        let executor = NativeCleanupExecutor(paths)

        await #expect(throws: CleanupMeasurementError.self) {
            try await executor.measureUsedSpace()
        }

        let result = await executor.perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test
    func rejectsARelativeFileTargetBeforeItCanReachAnExternalMarker() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let marker = fixture.externalDirectory.appending(path: "marker.data")
        try fixture.write(Data([1]), to: marker)
        let relativeTarget = try #require(URL(string: "file:DerivedData"))
        let paths = OverriddenCleanupPaths(fixture.libraryRoot, derivedData: relativeTarget)
        let executor = NativeCleanupExecutor(paths)

        await #expect(throws: CleanupMeasurementError.self) {
            try await executor.measureUsedSpace()
        }

        let result = await executor.perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }

    @Test
    func refusesAnAncestorSwapAfterValidationBeforeMeasurementOrRemoval() async throws {
        let fixture = try CleanupFixture()
        defer { fixture.remove() }

        let ancestor = fixture.libraryRoot.appending(path: "Developer", directoryHint: .isDirectory)
        let externalTarget = fixture.externalDirectory.appending(path: "Xcode/DerivedData", directoryHint: .isDirectory)
        let marker = externalTarget.appending(path: "marker.data")
        try fixture.write(Data(repeating: 1, count: 4_096), to: fixture.paths.derivedData.appending(path: "local.data"))
        try fixture.write(Data(repeating: 1, count: 4_096), to: marker)

        let measurementFileSystem = AncestorSwapFileSystem(ancestor, externalDirectory: fixture.externalDirectory)
        let measurementExecutor = NativeCleanupExecutor(fixture.paths, fileSystem: measurementFileSystem)

        await #expect(throws: CleanupMeasurementError.self) {
            try await measurementExecutor.measureUsedSpace()
        }

        #expect(FileManager.default.fileExists(atPath: marker.path))

        let removalFixture = try CleanupFixture()
        defer { removalFixture.remove() }

        let removalAncestor = removalFixture.libraryRoot.appending(path: "Developer", directoryHint: .isDirectory)
        let removalExternalTarget = removalFixture.externalDirectory.appending(path: "Xcode/DerivedData", directoryHint: .isDirectory)
        let removalMarker = removalExternalTarget.appending(path: "marker.data")
        try removalFixture.write(Data([1]), to: removalFixture.paths.derivedData.appending(path: "local.data"))
        try removalFixture.write(Data([1]), to: removalMarker)

        let removalFileSystem = AncestorSwapFileSystem(removalAncestor, externalDirectory: removalFixture.externalDirectory)
        let result = await NativeCleanupExecutor(removalFixture.paths, fileSystem: removalFileSystem).perform(.removeDerivedData)

        #expect(result.errors.count == 1)
        #expect(FileManager.default.fileExists(atPath: removalMarker.path))
    }

    @Test
    func delegatesOneMeasurementToTheAnchoredFileSystemPerConfiguredTarget() async throws {
        let root = URL(filePath: "/trusted", directoryHint: .isDirectory)
        let target = root.appending(path: "DerivedData", directoryHint: .isDirectory)
        let paths = OverriddenCleanupPaths(root, derivedData: target)
        let fileSystem = CountingFileSystem()
        let executor = NativeCleanupExecutor(paths, fileSystem: fileSystem)

        _ = try await executor.measureUsedSpace()

        #expect(fileSystem.measurementCallCount(for: target) == 1)
        #expect(fileSystem.totalMeasurementCallCount == 9)
    }
}

private final class CleanupFixture: @unchecked Sendable {

    // MARK: - Public Properties

    let rootDirectory: URL
    let externalDirectory: URL
    let libraryRoot: URL
    let paths: CleanupPaths

    // MARK: - Initializer

    init() throws {
        let rootDirectory = URL(filePath: "/private/tmp", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let externalDirectory = rootDirectory.appending(path: "external", directoryHint: .isDirectory)
        let libraryRoot = rootDirectory.appending(path: "library", directoryHint: .isDirectory)
        self.rootDirectory = rootDirectory
        self.externalDirectory = externalDirectory
        self.libraryRoot = libraryRoot
        paths = CleanupPaths(libraryRoot, root: .libraryDirectory)
        try FileManager.default.createDirectory(at: externalDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    func remove() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}

private struct FailingFileSystem: CleanupFileSystem {

    // MARK: - Private Properties

    private let failingURL: URL
    private let base = DescriptorAnchoredCleanupFileSystem()

    // MARK: - Initializer

    init(_ failingURL: URL) {
        self.failingURL = failingURL
    }

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupSecureTarget) throws -> Int64 {
        try base.allocatedSize(of: target)
    }

    func remove(target: CleanupSecureTarget) throws {
        if target.url == failingURL {
            throw CleanupFileSystemTestError.denied
        }

        try base.remove(target: target)
    }

    func isFileNotFound(_ error: Error) -> Bool {
        base.isFileNotFound(error)
    }
}

private actor PreferencesResetterSpy: XcodePreferencesResetting {

    // MARK: - Public Properties

    private(set) var resetCount = 0
    private(set) var domains = [String]()

    // MARK: - Public Methods

    func reset(_ domain: String) {
        resetCount += 1
        domains.append(domain)
    }
}

private struct RemovalRaceFileSystem: CleanupFileSystem {

    // MARK: - Initializer

    init(_ racingURL: URL) {}

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupSecureTarget) throws -> Int64 {
        0
    }

    func remove(target: CleanupSecureTarget) throws {
        throw RemovalRaceError.fileDisappeared
    }

    func isFileNotFound(_ error: Error) -> Bool {
        error as? RemovalRaceError == .fileDisappeared
    }
}

private final class AncestorSwapFileSystem: CleanupFileSystem, @unchecked Sendable {

    // MARK: - Private Properties

    private let ancestor: URL
    private let externalDirectory: URL
    private let base = DescriptorAnchoredCleanupFileSystem()
    private var hasSwapped = false

    // MARK: - Initializer

    init(_ ancestor: URL, externalDirectory: URL) {
        self.ancestor = ancestor
        self.externalDirectory = externalDirectory
    }

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupSecureTarget) throws -> Int64 {
        try swapAncestorAfterValidation()
        return try base.allocatedSize(of: target)
    }

    func remove(target: CleanupSecureTarget) throws {
        try swapAncestorAfterValidation()
        try base.remove(target: target)
    }

    func isFileNotFound(_ error: Error) -> Bool {
        base.isFileNotFound(error)
    }

    // MARK: - Private Methods

    private func swapAncestorAfterValidation() throws {
        guard !hasSwapped else {
            return
        }

        let displacedAncestor = ancestor.deletingLastPathComponent().appending(path: "displaced-ancestor", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: ancestor, to: displacedAncestor)
        try FileManager.default.createSymbolicLink(at: ancestor, withDestinationURL: externalDirectory)
        hasSwapped = true
    }
}

private struct OverriddenCleanupPaths: CleanupPathProviding {

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

    init(_ cleanupRoot: URL, derivedData: URL) {
        self.cleanupRoot = cleanupRoot
        self.derivedData = derivedData
        archives = cleanupRoot.appending(path: "Archives", directoryHint: .isDirectory)
        simulatorData = cleanupRoot.appending(path: "CoreSimulator", directoryHint: .isDirectory)
        xcodeCache = cleanupRoot.appending(path: "XcodeCache", directoryHint: .isDirectory)
        carthageCache = cleanupRoot.appending(path: "CarthageCache", directoryHint: .isDirectory)
        cocoaPodsCache = cleanupRoot.appending(path: "CocoaPods", directoryHint: .isDirectory)
        deviceSupportIOS = cleanupRoot.appending(path: "iOSDeviceSupport", directoryHint: .isDirectory)
        deviceSupportWatchOS = cleanupRoot.appending(path: "watchOSDeviceSupport", directoryHint: .isDirectory)
        deviceSupportTvOS = cleanupRoot.appending(path: "tvOSDeviceSupport", directoryHint: .isDirectory)
    }
}

private final class CountingFileSystem: CleanupFileSystem, @unchecked Sendable {

    // MARK: - Public Properties

    var totalMeasurementCallCount: Int {
        measurementCallCounts.values.reduce(0, +)
    }

    // MARK: - Private Properties

    private var measurementCallCounts = [URL: Int]()

    // MARK: - Public Methods

    func allocatedSize(of target: CleanupSecureTarget) throws -> Int64 {
        measurementCallCounts[target.url, default: 0] += 1
        return 1
    }

    func remove(target: CleanupSecureTarget) throws {}

    func isFileNotFound(_ error: Error) -> Bool {
        false
    }

    func measurementCallCount(for url: URL) -> Int {
        measurementCallCounts[url, default: 0]
    }
}

private enum CleanupFileSystemTestError: Error {
    case denied
}

private enum RemovalRaceError: Error, Equatable {
    case fileDisappeared
}
