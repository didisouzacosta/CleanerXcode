//
//  TemporaryItemInspectorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct TemporaryItemInspectorTests {

    // MARK: - Private Properties

    /// Kept as a suite property so the folder lives until the test ends.
    private let fixture: TemporaryDirectoryFixture
    private let inspector = TemporaryItemInspector()
    private let longAgo = Date(timeIntervalSince1970: 1_000_000_000)

    // MARK: - Initializers

    init() throws {
        fixture = try TemporaryDirectoryFixture()
    }

    // MARK: - Public Methods

    @Test
    func aFolderIsAsRecentAsItsNewestNestedItem() throws {
        let folder = try fixture.makeDirectory("build")
        let nested = try fixture.makeFile("build/deep/inside/new.o")
        try setModificationDate(longAgo, of: folder)
        try setModificationDate(longAgo, of: folder.appending(path: "deep"))
        try setModificationDate(longAgo, of: nested.deletingLastPathComponent())
        let recent = Date(timeIntervalSince1970: 1_700_000_000)
        try setModificationDate(recent, of: nested)

        let item = try #require(inspector.inspect(folder))

        #expect(item.name == "build")
        #expect(item.kind == .directory)
        #expect(item.ownerID == getuid())
        #expect(abs(item.newestModification.timeIntervalSince(recent)) < 1)
    }

    @Test
    func readsTheKindOfFilesLinksAndPipes() throws {
        let file = try fixture.makeFile("a.log")
        let link = fixture.url.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.url.appending(path: "gone"))
        let pipe = fixture.url.appending(path: "pipe")
        #expect(mkfifo(pipe.path(percentEncoded: false), 0o600) == 0)

        #expect(inspector.inspect(file)?.kind == .file)
        #expect(inspector.inspect(link)?.kind == .symbolicLink)
        #expect(inspector.inspect(pipe)?.kind == .other)
    }

    /// An age that cannot be verified must never make an item look old.
    @Test
    func aFolderWithAnUnreadablePartCountsAsRecent() throws {
        let folder = try fixture.makeDirectory("mixed")
        let locked = try fixture.makeDirectory("mixed/locked")
        try fixture.makeFile("mixed/locked/x")
        try setModificationDate(longAgo, of: folder)
        try fixture.setPermissions(0o000, of: locked)

        defer { try? fixture.setPermissions(0o755, of: locked) }

        #expect(inspector.inspect(folder)?.newestModification == .distantFuture)
    }

    @Test
    func findsSocketsAndPipesAnywhereInsideAFolder() throws {
        let folder = try fixture.makeDirectory("cc-socks")
        try fixture.makeDirectory("cc-socks/session")
        #expect(mkfifo(folder.appending(path: "session/4523.pipe").path(percentEncoded: false), 0o600) == 0)
        let plain = try fixture.makeDirectory("plain")
        try fixture.makeFile("plain/a.txt")

        #expect(inspector.inspect(folder)?.containsSpecialFiles == true)
        #expect(inspector.inspect(plain)?.containsSpecialFiles == false)
    }

    @Test
    func aShallowInspectionDoesNotWalkTheFolder() throws {
        let folder = try fixture.makeDirectory("big")
        let nested = try fixture.makeFile("big/new.o")
        try setModificationDate(longAgo, of: folder)
        try setModificationDate(Date(), of: nested)

        let shallow = try #require(inspector.inspect(folder, includingContents: false))

        #expect(abs(shallow.newestModification.timeIntervalSince(longAgo)) < 1)
        #expect(!shallow.containsSpecialFiles)
    }

    @Test
    func aFolderThatCannotBeListedCountsAsRecent() throws {
        let folder = try fixture.makeDirectory("sealed")
        try fixture.makeFile("sealed/x")
        try setModificationDate(longAgo, of: folder)
        try fixture.setPermissions(0o000, of: folder)

        defer { try? fixture.setPermissions(0o755, of: folder) }

        #expect(inspector.inspect(folder)?.newestModification == .distantFuture)
    }

    @Test
    func aCancelledWalkNeverMakesAFolderLookOld() async throws {
        let folder = try fixture.makeDirectory("old")
        try fixture.makeFile("old/a")
        try setModificationDate(longAgo, of: folder)
        let inspector = inspector

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return inspector.inspect(folder)
        }

        #expect(await task.value?.newestModification == .distantFuture)
    }

    @Test
    func aMissingItemCannotBeInspected() {
        #expect(inspector.inspect(fixture.url.appending(path: "missing")) == nil)
    }

    // MARK: - Private Methods

    private func setModificationDate(_ date: Date, of url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path(percentEncoded: false))
    }

}
