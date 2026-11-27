//
//  WatchedCategoryRootsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The folders the live measurement watches, and which categories a changed folder touches
/// (C40 · tempo real, R2, R5, R7). The catalog is built over `/Users/qa`, which this Mac does not
/// have, and the existing folders come from a dictionary, so nothing reads the disk.
struct WatchedCategoryRootsTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))

    private let xcode = "/Users/qa/Library/Developer/Xcode"

    // MARK: - Public Methods

    @Test
    func onlyExistingFoldersAreWatched() {
        let roots = resolve(existing: ["\(xcode)/DerivedData/", "\(xcode)/Archives/"])

        #expect(roots.directories == ["\(xcode)/Archives", "\(xcode)/DerivedData"])
    }

    @Test
    func theWatchedFoldersHaveNoDuplicatesAndAreSorted() {
        let roots = WatchedCategoryRoots.resolve(
            categories: catalog.categories,
            observing: LiveMeasurementPolicy.observedCategoryIDs
        ) { url in
            // Two roots resolving to the same real folder.
            url.path(percentEncoded: false).contains("Products") ? "\(xcode)/DerivedData" : nil
        }

        #expect(roots.directories == ["\(xcode)/DerivedData"])
    }

    @Test
    func unobservedCategoriesAreNeverWatched() {
        let roots = resolve(existing: ["/private/tmp/qa/", "/private/var/tmp/qa/", "/private/var/folders/qa/T/"])

        #expect(roots.directories.isEmpty)
    }

    @Test
    func aChangeAtTheRootOrBelowItTouchesItsCategory() {
        let roots = resolve(existing: [])

        #expect(roots.categories(affectedBy: [change("\(xcode)/DerivedData")]) == [.removeDerivedData])
        #expect(roots.categories(affectedBy: [change("\(xcode)/DerivedData/App-abc/Build")]) == [.removeDerivedData])
        #expect(roots.categories(affectedBy: [change("\(xcode)/DerivedData/")]) == [.removeDerivedData])
    }

    /// The default APFS volume ignores case.
    @Test
    func caseIsIgnored() {
        let roots = resolve(existing: [])

        #expect(roots.categories(affectedBy: [change("/users/QA/Library/Developer/Xcode/deriveddata/x")]) == [
            .removeDerivedData,
        ])
    }

    @Test
    func aSiblingWithTheSamePrefixIsNotTheRoot() {
        let roots = resolve(existing: [])

        #expect(roots.categories(affectedBy: [change("\(xcode)/DerivedDataOld/x")]).isEmpty)
    }

    @Test
    func excludedChildrenBelongToTheirOwnCategories() {
        let roots = resolve(existing: [])

        #expect(roots.categories(affectedBy: [change("\(xcode)/UserData/Previews/x")]) == [.clearAuxiliaryDeviceSets])
        #expect(roots.categories(affectedBy: [change("\(xcode)/UserData/KeyBindings")]) == [.removeXcodeUserData])
        #expect(roots.categories(
            affectedBy: [change("/Users/qa/Library/Developer/CoreSimulator/Caches/Personalization/x")]
        ).isEmpty)
        #expect(roots.categories(affectedBy: [change("/Users/qa/Library/Developer/CoreSimulator/Caches/dyld")]) == [
            .clearSimulatorCaches,
        ])
    }

    @Test
    func foldersOutsideTheObservedCategoriesTouchNothing() {
        let roots = resolve(existing: [])

        #expect(roots.categories(affectedBy: [
            change("/private/tmp/qa/x"),
            change("/private/var/tmp/qa/x"),
            change("/Users/qa/Library/Developer/Toolchains/x"),
            change("/Users/qa/Library/Developer/Xcode"),
        ]).isEmpty)
    }

    /// A root changed or events were dropped: every category at, above or below the path, with
    /// no exclusions.
    @Test
    func aRootChangeTouchesTheCategoriesAboveAndBelowThePath() {
        let roots = resolve(existing: [])

        #expect(roots.categories(affectedBy: [change("\(xcode)/UserData", kind: .rootChanged)]) == [
            .removeXcodeUserData,
            .removeProvisioningProfiles,
            .clearAuxiliaryDeviceSets,
        ])
        #expect(roots.categories(affectedBy: [change("\(xcode)/DerivedData/x", kind: .mustRescan)]) == [
            .removeDerivedData,
        ])
    }

    @Test
    func droppedEventsAtTheTopTouchEveryObservedCategory() {
        let roots = resolve(existing: [])

        #expect(roots.categories(affectedBy: [change("/", kind: .mustRescan)]) == LiveMeasurementPolicy
            .observedCategoryIDs)
    }

    @Test
    func onlyARootChangeAsksToWatchAgain() {
        let roots = resolve(existing: [])

        #expect(roots.needsRewatch([change("\(xcode)/DerivedData", kind: .rootChanged)]))
        #expect(!roots.needsRewatch([change("\(xcode)/DerivedData"), change("/", kind: .mustRescan)]))
    }

    /// The real check, inside a folder the test owns: a missing path, a file and a symbolic link are
    /// not watched, and a folder comes back with its real path.
    @Test
    func theRealCheckOnlyAcceptsFoldersThatAreNotLinks() throws {
        let fixture = try TemporaryDirectoryFixture()
        let folder = try fixture.makeDirectory("folder")
        let file = try fixture.makeFile("file")
        let link = fixture.url.appending(path: "link", directoryHint: .isDirectory)

        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)

        let resolved = try #require(WatchedCategoryRoots.existingDirectory(folder))

        #expect(resolved.hasPrefix("/private/"), "The real path keeps /private.")
        #expect(resolved.hasSuffix("/folder"))
        #expect(WatchedCategoryRoots.existingDirectory(file) == nil)
        #expect(WatchedCategoryRoots.existingDirectory(link) == nil)
        #expect(WatchedCategoryRoots.existingDirectory(fixture.url.appending(path: "missing")) == nil)
    }

    // MARK: - Private Methods

    private func resolve(existing: Set<String>) -> WatchedCategoryRoots {
        WatchedCategoryRoots.resolve(
            categories: catalog.categories,
            observing: LiveMeasurementPolicy.observedCategoryIDs
        ) { url in
            let path = url.path(percentEncoded: false)

            return existing.contains(path) ? String(path.dropLast()) : nil
        }
    }

    private func change(_ path: String, kind: FileSystemChange.Kind = .changed) -> FileSystemChange {
        FileSystemChange(path: path, kind: kind)
    }

}
