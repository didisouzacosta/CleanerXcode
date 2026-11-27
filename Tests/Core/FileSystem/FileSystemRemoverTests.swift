//
//  FileSystemRemoverTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct FileSystemRemoverTests {

    // MARK: - Private Properties

    /// Kept as a suite property so the folder lives until the test ends.
    private let fixture: TemporaryDirectoryFixture
    private let locations: CleanupLocations

    // MARK: - Initializers

    init() throws {
        let fixture = try TemporaryDirectoryFixture()

        self.fixture = fixture
        self.locations = try CleanupLocations(
            home: fixture.url,
            userTemporary: fixture.makeDirectory("folders/T"),
            systemTemporary: fixture.makeDirectory("tmp"),
            varTemporary: fixture.makeDirectory("var/tmp")
        )
    }

    // MARK: - Public Methods

    @Test
    func deletesEveryChildOneByOneWithItsSizeAndKeepsTheRoot() async throws {
        let root = try fixture.makeDirectory("DerivedData")
        let folderFiles = try [
            fixture.makeFile("DerivedData/App-abc/Build/x.o", bytes: 40_000),
            fixture.makeFile("DerivedData/App-abc/info.plist", bytes: 1_000),
        ]
        let file = try fixture.makeFile("DerivedData/loose.bin", bytes: 9_000)
        let hidden = try fixture.makeFile("DerivedData/.hidden", bytes: 2_000)
        let expected = try [
            item("~/DerivedData/.hidden", bytes: fixture.allocatedSize(of: [hidden]), .removed),
            item("~/DerivedData/App-abc", bytes: fixture.allocatedSize(of: folderFiles), .removed),
            item("~/DerivedData/loose.bin", bytes: fixture.allocatedSize(of: [file]), .removed),
        ]

        let results = try await removeContents(
            using: makeRemover(roots: [root]),
            of: CleanupTarget(root: root),
            categoryID: .removeDerivedData,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results == expected)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false)).isEmpty)
    }

    @Test
    func movesEachChildToTheTrashWhenTheModeIsTrash() async throws {
        let root = try fixture.makeDirectory("Archives")
        let archive = try fixture.makeFile("Archives/2026-10-31/App.xcarchive/Info.plist", bytes: 3_000)
        let operations = FileOperationsSpy()

        let results = try await removeContents(
            using: makeRemover(roots: [root], operations: operations),
            of: CleanupTarget(root: root),
            categoryID: .removeArchives,
            mode: .trash,
            filter: { _ in true }
        )

        #expect(try results == [item(
            "~/Archives/2026-10-31",
            bytes: fixture.allocatedSize(of: [archive]),
            .trashed,
            .removeArchives
        )])
        #expect(operations.trashedNames == ["2026-10-31"])
        #expect(operations.deletedNames.isEmpty)
    }

    @Test
    func aFolderThatCannotBeEmptiedFailsWithPermissionDeniedAndTheRestIsRemoved() async throws {
        let root = try fixture.makeDirectory("Caches")
        try fixture.makeFile("Caches/ok.bin", bytes: 1_000)
        try fixture.makeFile("Caches/locked/keep.bin", bytes: 1_000)
        let locked = root.appending(path: "locked", directoryHint: .isDirectory)
        try fixture.setPermissions(0o500, of: locked)

        defer { try? fixture.setPermissions(0o755, of: locked) }

        let results = try await removeContents(
            using: makeRemover(roots: [root]),
            of: CleanupTarget(root: root),
            categoryID: .removeCaches,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results.map(\.displayPath) == ["~/Caches/locked", "~/Caches/ok.bin"])
        #expect(results.first?.outcome == .failed(.permissionDenied))
        #expect(results.first?.bytes == 0)
        #expect(results.last?.outcome == .removed)
        #expect(FileManager.default.fileExists(atPath: locked.appending(path: "keep.bin").path(percentEncoded: false)))
        #expect(CleanupReport(results: results).outcome == .partialFailure)
    }

    @Test
    func anItemThatDisappearsIsSkippedInsteadOfFailing() async throws {
        let root = try fixture.makeDirectory("DerivedData")
        try fixture.makeFile("DerivedData/a", bytes: 1)
        let vanishing = try fixture.makeFile("DerivedData/b", bytes: 1)
        try fixture.makeFile("DerivedData/c", bytes: 1)
        let operations = FileOperationsSpy(failures: ["c": CocoaError(.fileNoSuchFile)])

        // Listed, then removed by someone else before its turn.
        let results = try await removeContents(
            using: makeRemover(roots: [root], operations: operations),
            of: CleanupTarget(root: root),
            categoryID: .removeDerivedData,
            mode: .delete,
            filter: { url in
                if url.lastPathComponent == "a" {
                    try? FileManager().removeItem(at: vanishing)
                }

                return true
            }
        )

        #expect(results.map(\.outcome) == [.removed, .skipped(.notFound), .skipped(.notFound)])
        #expect(CleanupReport(results: results).outcome == .success)
    }

    @Test
    func removesOnlyTheLinkWhenAChildIsASymbolicLink() async throws {
        let root = try fixture.makeDirectory("Caches")
        let outside = try fixture.makeDirectory("Documents")
        let thesis = try fixture.makeFile("Documents/thesis.pages", bytes: 5_000)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "folder-link"), withDestinationURL: outside)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "file-link"), withDestinationURL: thesis)

        let results = try await removeContents(
            using: makeRemover(roots: [root]),
            of: CleanupTarget(root: root),
            categoryID: .removeCaches,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results == [
            item("~/Caches/file-link", bytes: 0, .removed, .removeCaches),
            item("~/Caches/folder-link", bytes: 0, .removed, .removeCaches),
        ])
        #expect(FileManager.default.fileExists(atPath: thesis.path(percentEncoded: false)))
    }

    @Test
    func aRootThatIsASymbolicLinkIsSkippedWithoutTouchingItsTarget() async throws {
        let home = try fixture.makeDirectory("Users/tester")
        let thesis = try fixture.makeFile("Users/tester/thesis.pages", bytes: 5_000)
        let root = fixture.url.appending(path: "CocoaPods", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: home)
        let operations = FileOperationsSpy()

        let results = try await removeContents(
            using: makeRemover(roots: [root], operations: operations),
            of: CleanupTarget(root: root),
            categoryID: .removeCaches,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results == [item("~/CocoaPods", bytes: 0, .skipped(.unsupportedRoot), .removeCaches)])
        #expect(operations.deletedNames.isEmpty)
        #expect(FileManager.default.fileExists(atPath: thesis.path(percentEncoded: false)))
    }

    @Test
    func leavesExcludedAndFilteredChildrenAloneWithoutReportingThem() async throws {
        let root = try fixture.makeDirectory("UserData")
        let previews = try fixture.makeFile("UserData/Previews/device.img", bytes: 1)
        let young = try fixture.makeFile("UserData/young.tmp", bytes: 1)
        try fixture.makeFile("UserData/old.tmp", bytes: 1)

        let results = try await removeContents(
            using: makeRemover(roots: [root]),
            of: CleanupTarget(root: root, excludedNames: ["Previews"]),
            categoryID: .removeXcodeUserData,
            mode: .delete,
            filter: { $0.lastPathComponent != "young.tmp" }
        )

        #expect(results.map(\.displayPath) == ["~/UserData/old.tmp"])
        #expect(FileManager.default.fileExists(atPath: previews.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: young.path(percentEncoded: false)))
    }

    @Test
    func stopsBetweenItemsWhenTheCallerIsCancelledAndReportsWhatWasAlreadyRemoved() async throws {
        let root = try fixture.makeDirectory("DerivedData")

        for name in ["a", "b", "c"] {
            try fixture.makeFile("DerivedData/\(name)", bytes: 1)
        }

        // The spy cancels the task that called the remover, right after the first delete.
        let operations = FileOperationsSpy(cancelsAfterFirstDelete: true)
        let remover = makeRemover(roots: [root], operations: operations)
        let collector = CleanupResultCollector()

        let task = Task {
            try await remover.removeContents(
                of: CleanupTarget(root: root),
                categoryID: .removeDerivedData,
                mode: .delete,
                filter: { _ in true },
                onResult: collector.append
            )
        }

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(collector.results.map(\.displayPath) == ["~/DerivedData/a"])
        #expect(collector.results.map(\.outcome) == [.removed])
        #expect(operations.deletedNames == ["a"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false)).sorted() == [
            "b",
            "c",
        ])
    }

    @Test
    func mapsTheOperationErrorOfEachItem() async throws {
        let root = try fixture.makeDirectory("Caches")

        for name in ["busy", "denied", "odd"] {
            try fixture.makeFile("Caches/\(name)", bytes: 1)
        }

        let operations = FileOperationsSpy(failures: [
            "busy": POSIXError(.EBUSY),
            "denied": CocoaError(.fileWriteNoPermission),
            "odd": POSIXError(.EROFS),
        ])

        let results = try await removeContents(
            using: makeRemover(roots: [root], operations: operations),
            of: CleanupTarget(root: root),
            categoryID: .removeCaches,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results.map(\.outcome) == [
            .failed(.inUse),
            .failed(.permissionDenied),
            .failed(.unknown(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.EROFS.rawValue))),
        ])
        #expect(results.allSatisfy { $0.bytes == 0 })
    }

    @Test
    func anUnreadableRootIsReportedAsPermissionDenied() async throws {
        let root = try fixture.makeDirectory("Locked")
        try fixture.makeFile("Locked/a", bytes: 1)
        try fixture.setPermissions(0o000, of: root)

        defer { try? fixture.setPermissions(0o755, of: root) }

        let results = try await removeContents(
            using: makeRemover(roots: [root]),
            of: CleanupTarget(root: root),
            categoryID: .removeCaches,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results == [item("~/Locked", bytes: 0, .failed(.permissionDenied), .removeCaches)])
    }

    /// Readable but not searchable: listing already fails, so the root reports the real error.
    @Test
    func aRootThatCannotBeSearchedIsReportedAsPermissionDenied() async throws {
        let root = try fixture.makeDirectory("Caches")
        try fixture.makeFile("Caches/a.bin", bytes: 1)
        try fixture.setPermissions(0o600, of: root)

        defer { try? fixture.setPermissions(0o755, of: root) }

        let results = try await removeContents(
            using: makeRemover(roots: [root]),
            of: CleanupTarget(root: root),
            categoryID: .removeCaches,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results == [item("~/Caches", bytes: 0, .failed(.permissionDenied), .removeCaches)])
    }

    @Test
    func aMissingRootHasNothingToRemove() async throws {
        let root = fixture.url.appending(path: "DerivedData", directoryHint: .isDirectory)

        let results = try await removeContents(
            using: makeRemover(roots: [root]),
            of: CleanupTarget(root: root),
            categoryID: .removeDerivedData,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results.isEmpty)
    }

    @Test
    func aRootOutsideTheCatalogIsReportedAsUnsafeAndNothingIsRemoved() async throws {
        let known = try fixture.makeDirectory("DerivedData")
        let unknown = try fixture.makeDirectory("Documents")
        let thesis = try fixture.makeFile("Documents/thesis.pages", bytes: 1)

        let results = try await removeContents(
            using: makeRemover(roots: [known]),
            of: CleanupTarget(root: unknown),
            categoryID: .removeDerivedData,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results == [item("~/Documents", bytes: 0, .failed(.unsafePath))])
        #expect(FileManager.default.fileExists(atPath: thesis.path(percentEncoded: false)))
    }

    @Test
    func everyChildGoesThroughThePolicyBeforeBeingRemoved() async throws {
        let userData = try fixture.makeDirectory("UserData")
        let previews = try fixture.makeFile("UserData/Previews/device.img", bytes: 1)
        try fixture.makeFile("UserData/theme.xccolortheme", bytes: 1)
        let operations = FileOperationsSpy()
        let remover = FileSystemRemover(
            policy: SafePathPolicy(
                roots: [userData, userData.appending(path: "Previews", directoryHint: .isDirectory)],
                protectedPaths: [],
                allowedBases: [fixture.url]
            ),
            locations: locations,
            operations: operations
        )

        // Without the exclusion, the nested catalog root is still refused by the policy.
        let results = try await removeContents(
            using: remover,
            of: CleanupTarget(root: userData),
            categoryID: .removeXcodeUserData,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(results.map(\.outcome) == [.failed(.unsafePath), .removed])
        #expect(operations.deletedNames == ["theme.xccolortheme"])
        #expect(FileManager.default.fileExists(atPath: previews.path(percentEncoded: false)))
    }

    @Test
    @MainActor
    func removesOffTheMainThreadEvenWhenConsumedFromIt() async throws {
        let root = try fixture.makeDirectory("DerivedData")
        try fixture.makeFile("DerivedData/a", bytes: 1)
        let operations = FileOperationsSpy()

        _ = try await removeContents(
            using: makeRemover(roots: [root], operations: operations),
            of: CleanupTarget(root: root),
            categoryID: .removeDerivedData,
            mode: .delete,
            filter: { _ in true }
        )

        #expect(operations.operationsOnMainThread == [false])
    }

    // MARK: - Private Methods

    private func makeRemover(
        roots: [URL],
        operations: any FileOperating = FileManagerOperations()
    ) -> FileSystemRemover {
        FileSystemRemover(
            policy: SafePathPolicy(roots: roots, protectedPaths: [], allowedBases: [fixture.url]),
            locations: locations,
            operations: operations
        )
    }

    private func removeContents(
        using remover: FileSystemRemover,
        of target: CleanupTarget,
        categoryID: CleanupCategoryID,
        mode: RemovalMode,
        filter: @escaping @Sendable (URL) -> Bool
    ) async throws -> [CleanupItemResult] {
        let collector = CleanupResultCollector()

        try await remover.removeContents(
            of: target,
            categoryID: categoryID,
            mode: mode,
            filter: filter,
            onResult: collector.append
        )

        return collector.results
    }

    private func item(
        _ displayPath: String,
        bytes: Int64,
        _ outcome: CleanupItemResult.Outcome,
        _ categoryID: CleanupCategoryID = .removeDerivedData
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: categoryID, displayPath: displayPath, bytes: bytes, outcome: outcome)
    }

}
