//
//  SafePathPolicyTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct SafePathPolicyTests {

    // MARK: - Private Properties

    /// Kept as a suite property so the folder lives until the test ends.
    private let fixture: TemporaryDirectoryFixture

    // MARK: - Initializers

    init() throws {
        fixture = try TemporaryDirectoryFixture()
    }

    // MARK: - Public Methods

    @Test
    func acceptsADirectChildAndADeeperDescendantOfAKnownRoot() throws {
        let root = try fixture.makeDirectory("DerivedData")
        let child = try fixture.makeDirectory("DerivedData/App-abc")
        let deeper = try fixture.makeFile("DerivedData/App-abc/Build/x.o")
        let policy = makePolicy(roots: [root])

        #expect(throws: Never.self) { try policy.validate(child, in: CleanupTarget(root: root)) }
        #expect(throws: Never.self) { try policy.validate(deeper, in: CleanupTarget(root: root)) }
    }

    @Test
    func rejectsTheRootItselfAndItsAncestors() throws {
        let root = try fixture.makeDirectory("Library/Developer/Xcode/DerivedData")
        let target = CleanupTarget(root: root)
        let policy = makePolicy(roots: [root])

        #expect(throws: CleanupError.unsafePath) { try policy.validate(root, in: target) }
        #expect(throws: CleanupError.unsafePath) {
            try policy.validate(root.deletingLastPathComponent(), in: target)
        }
        #expect(throws: CleanupError.unsafePath) { try policy.validate(fixture.url, in: target) }
    }

    @Test
    func rejectsPathsOutsideTheRootIncludingDotDotEscapes() throws {
        let root = try fixture.makeDirectory("DerivedData")
        let sibling = try fixture.makeFile("Documents/thesis.pages")
        let escape = root.appending(path: "../Documents/thesis.pages")
        let policy = makePolicy(roots: [root])

        #expect(throws: CleanupError.unsafePath) { try policy.validate(sibling, in: CleanupTarget(root: root)) }
        #expect(throws: CleanupError.unsafePath) { try policy.validate(escape, in: CleanupTarget(root: root)) }
    }

    @Test
    func rejectsDotAndDotDotComponentsEvenWhenTheyStayInsideTheRoot() throws {
        let root = try fixture.makeDirectory("DerivedData")
        try fixture.makeDirectory("DerivedData/A")
        try fixture.makeFile("DerivedData/B")
        let policy = makePolicy(roots: [root])

        #expect(throws: CleanupError.unsafePath) {
            try policy.validate(root.appending(path: "A/../B"), in: CleanupTarget(root: root))
        }
        #expect(throws: CleanupError.unsafePath) {
            try policy.validate(root.appending(path: "./B"), in: CleanupTarget(root: root))
        }
    }

    @Test
    func rejectsRootsTheCatalogDoesNotKnow() throws {
        let knownRoot = try fixture.makeDirectory("DerivedData")
        let unknownRoot = try fixture.makeDirectory("Documents")
        let file = try fixture.makeFile("Documents/a.txt")
        let policy = makePolicy(roots: [knownRoot])

        #expect(throws: CleanupError.unsafePath) { try policy.validate(file, in: CleanupTarget(root: unknownRoot)) }
    }

    @Test
    func rejectsItemsReachedThroughASymlinkedFolderThatLeavesTheRoot() throws {
        let root = try fixture.makeDirectory("DerivedData")
        let outside = try fixture.makeDirectory("Documents")
        try fixture.makeFile("Documents/thesis.pages")
        let link = root.appending(path: "Linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let policy = makePolicy(roots: [root])

        #expect(throws: CleanupError.unsafePath) {
            try policy.validate(link.appending(path: "thesis.pages"), in: CleanupTarget(root: root))
        }
    }

    @Test
    func acceptsTheSymlinkItselfBecauseOnlyTheLinkIsRemoved() throws {
        let root = try fixture.makeDirectory("DerivedData")
        let outside = try fixture.makeDirectory("Documents")
        let link = root.appending(path: "Linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let policy = makePolicy(roots: [root])

        #expect(throws: Never.self) { try policy.validate(link, in: CleanupTarget(root: root)) }
    }

    /// For example `/var/folders/…/T`, where `/var` is a symlink above the base.
    @Test
    func acceptsRootsWhoseBaseIsReachedThroughASymlink() throws {
        try fixture.makeDirectory("real/T")
        let child = try fixture.makeFile("real/T/item")
        let alias = fixture.url.appending(path: "alias", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.url.appending(path: "real"))
        let root = alias.appending(path: "T", directoryHint: .isDirectory)
        let policy = SafePathPolicy(roots: [root], protectedPaths: [], allowedBases: [alias])

        #expect(throws: Never.self) { try policy.validate(child, in: CleanupTarget(root: root)) }
    }

    /// For example `CoreSimulator` pointing at `~/Library`, which would make `CoreSimulator/Caches`
    /// land on `~/Library/Caches` while staying inside the base.
    @Test
    func rootWithASymlinkBetweenTheBaseAndItselfIsUnsupported() throws {
        let base = try fixture.makeDirectory("Library")
        try fixture.makeFile("Library/Caches/com.apple.Safari/Cache.db")
        try fixture.makeDirectory("Library/Developer")
        try FileManager.default.createSymbolicLink(
            at: base.appending(path: "Developer/CoreSimulator"),
            withDestinationURL: base
        )
        let root = base.appending(path: "Developer/CoreSimulator/Caches", directoryHint: .isDirectory)
        let policy = SafePathPolicy(roots: [root], protectedPaths: [], allowedBases: [base])

        #expect(throws: CleanupError.unsupportedRoot) { try policy.validateRoot(CleanupTarget(root: root)) }
    }

    @Test
    func rootOutsideEveryAllowedBaseIsUnsupported() throws {
        let base = try fixture.makeDirectory("Library")
        let root = try fixture.makeDirectory("Documents")
        let policy = SafePathPolicy(roots: [root], protectedPaths: [], allowedBases: [base])

        #expect(throws: CleanupError.unsupportedRoot) { try policy.validateRoot(CleanupTarget(root: root)) }
    }

    @Test
    func inspectorOnlyTreatsMissingItemsAsMissing() throws {
        let inspector = FileSystemPathInspector()
        let file = try fixture.makeFile("a.txt")
        let dangling = fixture.url.appending(path: "dangling")
        try FileManager.default.createSymbolicLink(
            at: dangling,
            withDestinationURL: fixture.url.appending(path: "gone")
        )
        let locked = try fixture.makeDirectory("locked")
        let insideLocked = try fixture.makeFile("locked/b.txt")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: locked.path(percentEncoded: false)
        )

        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: locked.path(percentEncoded: false)
            )
        }

        #expect(inspector.existence(of: file) == .present)
        #expect(inspector.existence(of: dangling) == .present)
        #expect(inspector.existence(of: insideLocked) == .unreadable(.permissionDenied))
        #expect(inspector.existence(of: fixture.url.appending(path: "missing")) == .missing)
        #expect(inspector.existence(of: file.appending(path: "child")) == .missing, "ENOTDIR means missing.")
    }

    /// For example `~/Library/Caches/CocoaPods` pointing at `~`: the root itself is never followed.
    @Test
    func rootThatIsASymlinkIsUnsupported() throws {
        let home = try fixture.makeDirectory("home")
        try fixture.makeFile("home/Documents/thesis.pages")
        try fixture.makeDirectory("base/Caches")
        let root = fixture.url.appending(path: "base/Caches/CocoaPods", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: home)
        let policy = SafePathPolicy(
            roots: [root],
            protectedPaths: [home],
            allowedBases: [fixture.url.appending(path: "base", directoryHint: .isDirectory)]
        )

        #expect(throws: CleanupError.unsupportedRoot) {
            try policy.validate(root.appending(path: "Documents"), in: CleanupTarget(root: root))
        }
        #expect(throws: CleanupError.unsupportedRoot) { try policy.validateRoot(CleanupTarget(root: root)) }
    }

    /// For example DerivedData moved to an external disk and replaced by a symlink.
    @Test
    func rootThatIsASymlinkIsUnsupportedEvenWhenItsTargetLooksHarmless() throws {
        let base = try fixture.makeDirectory("base")
        try fixture.makeFile("base/External/Build-abc/x.o")
        let root = base.appending(path: "DerivedData", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: base.appending(path: "External"))
        let policy = SafePathPolicy(roots: [root], protectedPaths: [], allowedBases: [base])

        #expect(throws: CleanupError.unsupportedRoot) {
            try policy.validate(root.appending(path: "Build-abc"), in: CleanupTarget(root: root))
        }
    }

    @Test
    func rootWhoseAncestorsLeadOutsideTheAllowedBaseIsUnsupported() throws {
        try fixture.makeDirectory("elsewhere/CocoaPods")
        try fixture.makeFile("elsewhere/CocoaPods/item")
        let base = try fixture.makeDirectory("base")
        try FileManager.default.createSymbolicLink(
            at: base.appending(path: "Caches"),
            withDestinationURL: fixture.url.appending(path: "elsewhere")
        )
        let root = base.appending(path: "Caches/CocoaPods", directoryHint: .isDirectory)
        let policy = SafePathPolicy(roots: [root], protectedPaths: [], allowedBases: [base])

        #expect(throws: CleanupError.unsupportedRoot) {
            try policy.validate(root.appending(path: "item"), in: CleanupTarget(root: root))
        }
    }

    @Test
    func rootThatContainsAProtectedPathIsUnsupported() throws {
        let home = try fixture.makeDirectory("home")
        try fixture.makeFile("home/a")
        let policy = SafePathPolicy(roots: [fixture.url], protectedPaths: [home], allowedBases: [fixture.url])

        #expect(throws: CleanupError.unsupportedRoot) {
            try policy.validate(home.appending(path: "a"), in: CleanupTarget(root: fixture.url))
        }
    }

    @Test
    func missingItemIsNotFoundInsteadOfABug() throws {
        let root = try fixture.makeDirectory("DerivedData")
        let policy = makePolicy(roots: [root])

        #expect(throws: CleanupError.notFound) {
            try policy.validate(root.appending(path: "Gone-abc"), in: CleanupTarget(root: root))
        }
    }

    /// A folder that can be read but not searched hides its items' attributes.
    @Test
    func itemThatCannotBeLookedUpIsPermissionDeniedInsteadOfUnsafe() throws {
        let root = try fixture.makeDirectory("Caches")
        let item = try fixture.makeFile("Caches/a.bin")
        let policy = makePolicy(roots: [root])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: root.path(percentEncoded: false)
        )

        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: root.path(percentEncoded: false)
            )
        }

        #expect(throws: CleanupError.permissionDenied) { try policy.validate(item, in: CleanupTarget(root: root)) }
    }

    @Test
    func excludedChildrenAndNestedCatalogRootsAreRejected() throws {
        let userData = try fixture.makeDirectory("UserData")
        let previews = try fixture.makeDirectory("UserData/Previews")
        let profiles = try fixture.makeDirectory("UserData/Provisioning Profiles")
        let profile = try fixture.makeFile("UserData/Provisioning Profiles/a.mobileprovision")
        let target = CleanupTarget(root: userData, excludedNames: ["Provisioning Profiles"])
        let policy = makePolicy(roots: [userData, previews])

        #expect(throws: CleanupError.unsafePath) { try policy.validate(profiles, in: target) }
        #expect(throws: CleanupError.unsafePath) { try policy.validate(profile, in: target) }
        #expect(throws: CleanupError.unsafePath) { try policy.validate(previews, in: target) }
    }

    @Test
    func rejectsItemsOnAnotherVolume() throws {
        let root = try fixture.makeDirectory("DerivedData")
        let mounted = try fixture.makeDirectory("DerivedData/MountedDisk")
        let policy = SafePathPolicy(
            roots: [root],
            protectedPaths: [],
            allowedBases: [fixture.url],
            inspector: VolumeInspectorStub(foreignPaths: [mounted.path()])
        )

        #expect(throws: CleanupError.unsafePath) { try policy.validate(mounted, in: CleanupTarget(root: root)) }
    }

    @Test
    func everyRealCatalogRootPassesItsOwnPolicy() throws {
        let locations = try CleanupLocations(
            home: fixture.makeDirectory("home"),
            userTemporary: fixture.makeDirectory("folders/ab/cd/T"),
            systemTemporary: fixture.makeDirectory("tmp"),
            varTemporary: fixture.makeDirectory("var/tmp")
        )
        let catalog = CleanupCatalog(locations: locations)
        let policy = catalog.makeSafePathPolicy()
        let userData = try #require(catalog[.removeXcodeUserData].targets.first)
        let preview = try fixture.makeFile("home/Library/Developer/Xcode/UserData/Previews/Simulator Devices/x")
        let theme = try fixture.makeFile("home/Library/Developer/Xcode/UserData/FontAndColorThemes/a.xccolortheme")

        for target in catalog.categories.flatMap(\.targets) {
            #expect(throws: Never.self) { try policy.validateRoot(target) }
        }

        #expect(throws: Never.self) { try policy.validate(theme, in: userData) }
        #expect(throws: CleanupError.unsafePath) { try policy.validate(preview, in: userData) }
    }

    @Test
    func catalogPolicyProtectsHomeLibraryAndTheFileSystemRoot() {
        let locations = CleanupLocations.current()
        let policy = CleanupCatalog(locations: locations).makeSafePathPolicy()
        let protected = Set(policy.protectedPaths.map { $0.path(percentEncoded: false) })
        let bases = policy.allowedBases

        #expect(protected.contains("/"))
        #expect(protected.contains(locations.home.path(percentEncoded: false)))
        #expect(protected.contains(locations.home.appending(path: "Library/").path(percentEncoded: false)))
        #expect(bases == [
            locations.home.appending(path: "Library", directoryHint: .isDirectory),
            locations.userTemporary,
            locations.systemTemporary,
            locations.varTemporary,
        ])
    }

    // MARK: - Private Methods

    private func makePolicy(roots: [URL]) -> SafePathPolicy {
        SafePathPolicy(roots: roots, protectedPaths: [], allowedBases: [fixture.url])
    }

}

nonisolated private struct VolumeInspectorStub: PathInspecting {

    // MARK: - Public Properties

    let foreignPaths: Set<String>

    // MARK: - Public Methods

    func existence(of url: URL) -> PathExistence {
        FileSystemPathInspector().existence(of: url)
    }

    func isSymbolicLink(_ url: URL) -> Bool {
        FileSystemPathInspector().isSymbolicLink(url)
    }

    func volumeURL(of url: URL) -> URL? {
        if foreignPaths.contains(url.path()) {
            return URL(filePath: "/Volumes/External", directoryHint: .isDirectory)
        }

        return URL(filePath: "/", directoryHint: .isDirectory)
    }

}
