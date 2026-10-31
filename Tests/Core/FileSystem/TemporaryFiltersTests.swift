//
//  TemporaryFiltersTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The filters and the filtered measurement on a temporary folder the test creates.
struct TemporaryFiltersTests {

    // MARK: - Private Properties

    /// Kept as a suite property so the folder lives until the test ends.
    private let fixture: TemporaryDirectoryFixture
    private let policy = TemporaryItemsPolicy(minimumAgeInDays: 3, userID: getuid(), appBundleIdentifier: "app.Cleaner")
    private let now = Date()
    private let known = "AAAA0000-0000-0000-0000-000000000001"
    private let gone = "BBBB0000-0000-0000-0000-000000000002"
    private let goneRecently = "CCCC0000-0000-0000-0000-000000000003"

    // MARK: - Initializers

    init() throws {
        fixture = try TemporaryDirectoryFixture()
    }

    // MARK: - Public Methods

    @Test
    func theTemporaryFilesFilterOnlyAcceptsOldItemsThatAreNotExcluded() throws {
        let root = try fixture.makeDirectory("tmp")
        let old = try makeItem("tmp/old-cache", ageInDays: 10)
        let recent = try makeItem("tmp/claude-501", ageInDays: 0)
        let launchd = try makeItem("tmp/com.apple.launchd.abc", ageInDays: 10)
        let simulator = try makeItem("tmp/com.apple.CoreSimulator.SimDevice.\(gone)", ageInDays: 10)
        let filter = TemporaryFilters.temporaryFiles(policy: policy, now: now)

        #expect(filter(old))
        #expect(!filter(recent))
        #expect(!filter(launchd))
        #expect(!filter(simulator), "F19 items are left to the orphan category.")
        #expect(!filter(root.appending(path: "missing")))
    }

    @Test
    func theOrphanFilterOnlyAcceptsOldFoldersOfDeletedSimulators() throws {
        try fixture.makeDirectory("var/tmp")
        let orphan = try makeItem("var/tmp/com.apple.CoreSimulator.SimDevice.\(gone)", ageInDays: 10)
        let fresh = try makeItem("var/tmp/com.apple.CoreSimulator.SimDevice.\(goneRecently)", ageInDays: 0)
        let live = try makeItem("var/tmp/com.apple.CoreSimulator.SimDevice.\(known)", ageInDays: 10)
        let unrelated = try makeItem("var/tmp/old-cache", ageInDays: 10)
        let filter = TemporaryFilters.orphanSimulatorTemp(
            finder: OrphanSimulatorTempFinder(knownUDIDs: [known]),
            policy: policy,
            now: now
        )

        #expect(filter(orphan))
        #expect(!filter(fresh))
        #expect(!filter(live))
        #expect(!filter(unrelated))
    }

    @Test
    func aFolderWithALivePipeInsideIsOnlyRemovedWhenItIsASimulatorOrphan() throws {
        try fixture.makeDirectory("tmp")
        let session = try makeItem("tmp/tmux-501", ageInDays: 10)
        try fixture.makeDirectory("var/tmp")
        let orphan = try makeItem("var/tmp/com.apple.CoreSimulator.SimDevice.\(gone)", ageInDays: 10)

        // Everything is old, so only the pipe can keep the session folder.
        for folder in [session, orphan] {
            let pipe = folder.appending(path: "pipe")
            #expect(mkfifo(pipe.path(percentEncoded: false), 0o600) == 0)

            for item in [pipe, folder] {
                try FileManager.default.setAttributes(
                    [.modificationDate: now.addingTimeInterval(-10 * 86_400)],
                    ofItemAtPath: item.path(percentEncoded: false)
                )
            }
        }

        #expect(!TemporaryFilters.temporaryFiles(policy: policy, now: now)(session))
        #expect(TemporaryFilters.orphanSimulatorTemp(
            finder: OrphanSimulatorTempFinder(knownUDIDs: [known]),
            policy: policy,
            now: now
        )(orphan))
    }

    @Test
    func temporaryCategoriesWithoutTheirFilterAreNeverMeasuredRaw() async throws {
        let root = try fixture.makeDirectory("tmp")
        let category = CleanupCategory(
            id: .clearTemporaryFiles,
            targets: [CleanupTarget(root: root)],
            operation: .removeTemporaryItems,
            risk: .attention,
            isEnabledByDefault: false
        )

        var results: [CategorySize] = []

        try await CategorySizeMeasurer(scanner: DiskUsageScannerStub(sizes: [root: 999_999])).measure([category]) {
            results.append($0)
        }

        #expect(results.isEmpty)
    }

    @Test
    func theFilteredMeasurementOnlyCountsAcceptedChildren() async throws {
        let root = try fixture.makeDirectory("tmp")
        let counted = try fixture.makeFile("tmp/old/a.bin", bytes: 20_000)
        try fixture.makeFile("tmp/kept.bin", bytes: 50_000)
        let measurer = FilteredContentsMeasurer()

        let bytes = try await measurer.allocatedSize(of: CleanupTarget(root: root)) { $0.lastPathComponent == "old" }

        #expect(try bytes == (fixture.allocatedSize(of: [counted])))
        #expect(try await measurer.allocatedSize(of: CleanupTarget(root: root.appending(path: "missing"))) { _ in
            true
        } == 0)
    }

    @Test
    func categoriesWithAFilterAreMeasuredThroughIt() async throws {
        let root = try fixture.makeDirectory("tmp")
        let counted = try fixture.makeFile("tmp/old.bin", bytes: 30_000)
        try fixture.makeFile("tmp/new.bin", bytes: 60_000)
        let category = CleanupCategory(
            id: .clearTemporaryFiles,
            targets: [CleanupTarget(root: root)],
            operation: .removeTemporaryItems,
            risk: .attention,
            isEnabledByDefault: false
        )

        var results: [CategorySize] = []

        try await CategorySizeMeasurer(scanner: DiskUsageScannerStub(sizes: [root: 999_999])).measure(
            [category],
            filters: [.clearTemporaryFiles: { $0.lastPathComponent == "old.bin" }]
        ) { results.append($0) }

        #expect(try results == [CategorySize(
            categoryID: .clearTemporaryFiles,
            bytes: fixture.allocatedSize(of: [counted])
        )])
    }

    // MARK: - Private Methods

    private func makeItem(_ path: String, ageInDays: Double) throws -> URL {
        let item = try fixture.makeDirectory(path)
        let date = now.addingTimeInterval(-ageInDays * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: item.path(percentEncoded: false))
        return item
    }

}
