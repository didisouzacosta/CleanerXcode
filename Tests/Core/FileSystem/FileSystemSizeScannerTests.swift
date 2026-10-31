//
//  FileSystemSizeScannerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
import Testing
@testable import CleanerXcode

struct FileSystemSizeScannerTests {

    // MARK: - Private Properties

    /// Kept as a suite property so the folder lives until the test ends.
    private let fixture: TemporaryDirectoryFixture
    private let scanner = FileSystemSizeScanner()

    // MARK: - Initializers

    init() throws {
        fixture = try TemporaryDirectoryFixture()
    }

    // MARK: - Public Methods

    @Test
    func sumsTheAllocatedSizeOfEveryFileInTheTreeIncludingHiddenFilesAndPackages() async throws {
        let root = try fixture.makeDirectory("DerivedData")
        let files = try [
            fixture.makeFile("DerivedData/App-abc/Build/Intermediates/x.o", bytes: 100_000),
            fixture.makeFile("DerivedData/App-abc/info.plist", bytes: 1_234),
            fixture.makeFile("DerivedData/.hidden", bytes: 5_000),
            fixture.makeFile("DerivedData/App-abc/Build/Products/App.app/Contents/MacOS/App", bytes: 20_000),
        ]
        let expected = try allocatedSize(of: files)

        let measured = try await scanner.allocatedSize(of: CleanupTarget(root: root))

        #expect(expected > 0)
        #expect(measured == expected)
    }

    @Test
    func measuresZeroForAnEmptyOrMissingRoot() async throws {
        let empty = try fixture.makeDirectory("Empty")
        let missing = fixture.url.appending(path: "Missing", directoryHint: .isDirectory)

        #expect(try await scanner.allocatedSize(of: CleanupTarget(root: empty)) == 0)
        #expect(try await scanner.allocatedSize(of: CleanupTarget(root: missing)) == 0)
    }

    @Test
    func doesNotFollowSymbolicLinksThatPointOutsideTheRoot() async throws {
        let root = try fixture.makeDirectory("Caches")
        let inside = try fixture.makeFile("Caches/inside.bin", bytes: 4_096)
        let outsideDirectory = try fixture.makeDirectory("Documents")
        let outsideFile = try fixture.makeFile("Documents/thesis.pages", bytes: 300_000)
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "documents-link"),
            withDestinationURL: outsideDirectory
        )
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "thesis-link"),
            withDestinationURL: outsideFile
        )

        let measured = try await scanner.allocatedSize(of: CleanupTarget(root: root))

        #expect(try measured == allocatedSize(of: [inside]))
    }

    @Test
    func measuresZeroWhenTheRootItselfIsASymbolicLink() async throws {
        let real = try fixture.makeDirectory("External/DerivedData")
        try fixture.makeFile("External/DerivedData/App/x.o", bytes: 50_000)
        let root = fixture.url.appending(path: "DerivedData", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: real)

        #expect(try await scanner.allocatedSize(of: CleanupTarget(root: root)) == 0)
    }

    @Test
    func skipsExcludedDirectChildrenButNotDeeperItemsWithTheSameName() async throws {
        let root = try fixture.makeDirectory("UserData")
        try fixture.makeFile("UserData/Previews/Simulator Devices/big.img", bytes: 200_000)
        try fixture.makeFile("UserData/Provisioning Profiles/a.mobileprovision", bytes: 8_000)
        let counted = try [
            fixture.makeFile("UserData/KeyBindings/Default.idekeybindings", bytes: 2_000),
            fixture.makeFile("UserData/Themes/Previews/theme.png", bytes: 10_000),
        ]
        let target = CleanupTarget(root: root, excludedNames: ["Previews", "Provisioning Profiles"])

        let measured = try await scanner.allocatedSize(of: target)

        #expect(try measured == allocatedSize(of: counted))
    }

    @Test
    func countsAnUnreadableSubfolderAsZeroAndKeepsMeasuringTheRest() async throws {
        let root = try fixture.makeDirectory("Caches")
        let readable = try fixture.makeFile("Caches/readable/a.bin", bytes: 12_000)
        try fixture.makeFile("Caches/locked/b.bin", bytes: 90_000)
        let locked = root.appending(path: "locked", directoryHint: .isDirectory)
        try setPermissions(0o000, of: locked)

        defer { try? setPermissions(0o755, of: locked) }

        let measured = try await scanner.allocatedSize(of: CleanupTarget(root: root))

        #expect(try measured == allocatedSize(of: [readable]))
    }

    @Test
    func throwsPermissionDeniedWhenTheRootCannotBeRead() async throws {
        let root = try fixture.makeDirectory("Locked")
        try fixture.makeFile("Locked/a.bin", bytes: 1_000)
        try setPermissions(0o000, of: root)

        defer { try? setPermissions(0o755, of: root) }

        await #expect(throws: CleanupError.permissionDenied) {
            try await scanner.allocatedSize(of: CleanupTarget(root: root))
        }
    }

    @Test
    func stopsWithinOneBatchWhenCancelledDuringTheScan() async throws {
        let itemCount = FileSystemSizeScanner.cancellationCheckInterval * 2 + 1
        let root = try fixture.makeDirectory("DerivedData")

        for index in 0..<itemCount {
            try fixture.makeFile("DerivedData/file-\(index)", bytes: 1)
        }
        // The factory runs after the initial cancellation check, so only the checks inside the
        // enumeration loop can stop the scan.
        let cancellingScanner = FileSystemSizeScanner(makeFileManager: {
            withUnsafeCurrentTask { $0?.cancel() }
            return FileManager()
        })

        let task = Task {
            try await cancellingScanner.allocatedSize(of: CleanupTarget(root: root))
        }

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    func throwsCancellationErrorWhenAlreadyCancelled() async throws {
        let root = try fixture.makeDirectory("DerivedData")
        try fixture.makeFile("DerivedData/x.o", bytes: 1_000)
        let scanner = scanner

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await scanner.allocatedSize(of: CleanupTarget(root: root))
        }

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    @MainActor
    func runsOffTheMainActorEvenWhenCalledFromIt() async throws {
        let root = try fixture.makeDirectory("DerivedData")
        let probe = ThreadProbe()
        let probingScanner = FileSystemSizeScanner(makeFileManager: {
            probe.record(isMainThread: Thread.isMainThread)
            return FileManager()
        })

        _ = try await probingScanner.allocatedSize(of: CleanupTarget(root: root))

        #expect(probe.recordedIsMainThread == false)
    }

    // MARK: - Private Methods

    /// The expected value, read item by item and independently of the scanner.
    private func allocatedSize(of files: [URL]) throws -> Int64 {
        try files.reduce(into: 0) { total, file in
            let fresh = URL(filePath: file.path(percentEncoded: false), directoryHint: .notDirectory)
            let values = try fresh.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            try total += Int64(#require(values.totalFileAllocatedSize))
        }
    }

    private func setPermissions(_ permissions: Int, of url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: url.path(percentEncoded: false)
        )
    }

    // MARK: - Nested Types

    nonisolated private final class ThreadProbe: Sendable {

        // MARK: - Public Properties

        var recordedIsMainThread: Bool? {
            state.withLock { $0 }
        }

        // MARK: - Private Properties

        private let state = Mutex<Bool?>(nil)

        // MARK: - Public Methods

        func record(isMainThread: Bool) {
            state.withLock { $0 = isMainThread }
        }

    }

}
