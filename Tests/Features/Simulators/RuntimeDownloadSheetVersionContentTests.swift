//
//  RuntimeDownloadSheetVersionContentTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The versions in the "Download runtimes" sheet (C35, R4, R5, R6, R11, AC6, AC13): each platform's
/// menu, the chosen version, the note while the versions load or when they are unavailable, and the
/// note about earlier versions.
struct RuntimeDownloadSheetVersionContentTests {

    // MARK: - Private Properties

    private let prefix = "com.apple.CoreSimulator.SimRuntime."

    /// iOS 27.2 (bundled with Xcode) and 27.1 installed, as in the previews and the Figma frames.
    private var installed: [SimulatorRuntime] {
        [
            runtime(prefix + "iOS-27-2", version: "27.2"),
            runtime(prefix + "iOS-27-1", version: "27.1"),
        ]
    }

    // MARK: - Public Methods

    @Test
    func eachPlatformOffersXcodesVersionFirstAndTheEarlierOnes() throws {
        let content = try content(versions: loaded())
        let iOS = try #require(content.rows.first)

        #expect(iOS.options.map(\.title) == [String(localized: "\("27.2") (Xcode)"), "26.5", "26.1", "26.0"])
        #expect(iOS.options.map(\.sizeBytes) == [8_321_588_736, 8_522_901_969, 8_321_575_375, 7_986_028_446])
        #expect(content.rows.allSatisfy { $0.selectedOption == $0.options.first })
        #expect(content.rows.map { $0.options.count } == [4, 2, 1, 2])
        #expect(content.versionsNote == nil)
        #expect(!content.showsEarlierVersionNote)
    }

    /// AC13: the note about earlier versions shows only when a checked platform has one chosen.
    @Test
    func aChosenEarlierVersionIsShownWithItsNote() throws {
        var choice = RuntimeDownloadChoice()

        try choice.select(version("26.5"), for: .iOS)
        choice.toggle(.watchOS)

        let content = try content(choice: choice, versions: loaded())

        #expect(content.rows[0].selectedOption.version?.rawValue == "26.5")
        #expect(content.rows[0].isSelected)
        #expect(content.rows[1].selectedOption.version == nil)
        #expect(content.showsEarlierVersionNote)
        #expect(content.selectionSummary == String(localized: "\(2) selected"))
        #expect(String(localized: content.confirmTitle) == String(localized: "Download \(2) runtimes"))

        choice.toggle(.iOS)

        let unchecked = try self.content(choice: choice, versions: loaded())

        #expect(unchecked.rows[0].selectedOption.version?.rawValue == "26.5", "Unchecking keeps the version.")
        #expect(!unchecked.showsEarlierVersionNote)
    }

    /// A chosen version the menu does not offer shows Xcode's, as it is what would be downloaded.
    @Test
    func aChosenVersionNotOfferedShowsXcodesVersion() throws {
        var choice = RuntimeDownloadChoice()

        try choice.select(version("27.1"), for: .iOS)

        let content = try content(choice: choice, versions: loaded())

        #expect(content.rows[0].selectedOption.version == nil)
        #expect(!content.showsEarlierVersionNote)
    }

    /// AC7: the sheet works at once while the versions load, with Xcode's version only.
    @Test
    func whileLoadingOnlyXcodesVersionWithTheLoadingNote() {
        let content = RuntimeDownloadSheetContent(
            choice: RuntimeDownloadChoice(),
            runtimes: installed,
            versions: nil,
            isLoadingVersions: true
        )

        #expect(content.rows.allSatisfy { $0.options.map(\.title) == [String(localized: "Xcode version")] })
        #expect(content.rows.allSatisfy { $0.options.first?.sizeBytes == nil })
        #expect(content.versionsNote == .loading)
        #expect(content.versionsNote?.text.key == "Loading earlier versions…")
    }

    /// Loading again keeps the last versions in the menus.
    @Test
    func loadingAgainKeepsTheLastVersions() throws {
        let content = try content(versions: loaded(), isLoading: true)

        #expect(content.rows[0].options.count == 4)
        #expect(content.versionsNote == .loading)
    }

    /// AC6: without the catalog or the SDK versions, only Xcode's version, with a note and "Try again".
    @Test
    func unavailableVersionsLeaveOnlyXcodesVersionWithANote() throws {
        let version = try #require(RuntimeBuildVersion("27.2"))
        let withoutCatalog = try content(versions: RuntimeVersionsSnapshot(sdkVersions: [.iOS: version], catalog: nil))
        let withoutSDKs = try content(versions: RuntimeVersionsSnapshot(sdkVersions: [:], catalog: loaded().catalog))

        #expect(withoutCatalog.versionsNote == .unavailable)
        #expect(withoutCatalog.rows[0].options.map(\.title) == [String(localized: "\("27.2") (Xcode)")])
        #expect(withoutSDKs.versionsNote == .unavailable)
        #expect(withoutSDKs.rows.allSatisfy { $0.options.count == 1 })
        #expect(withoutCatalog.versionsNote?.text.key == """
        Earlier versions are unavailable right now. You can still download the version that matches Xcode.
        """)
    }

    /// B1: the sheet always loads when it opens, so versions never loaded read as loading, not as
    /// unavailable, even in the first frame, before the load has started.
    @Test
    func versionsNeverLoadedReadAsLoading() throws {
        let content = try content(versions: nil, isLoading: false)

        #expect(content.versionsNote == .loading)
        #expect(content.rows.allSatisfy { $0.options.map(\.title) == [String(localized: "Xcode version")] })
    }

    /// B2, F3: with the SDK versions and the catalog still loading, Xcode's version has its number
    /// and no size, with the loading note.
    @Test
    func theSDKVersionsAloneShowXcodesNumberWhileLoading() throws {
        let sdkOnly = try RuntimeVersionsSnapshot(sdkVersions: loaded().sdkVersions, catalog: nil)

        let content = try content(versions: sdkOnly, isLoading: true)

        #expect(content.rows.allSatisfy { $0.options.map(\.title) == [String(localized: "\("27.2") (Xcode)")] })
        #expect(content.rows.allSatisfy { $0.options.first?.sizeBytes == nil })
        #expect(content.versionsNote == .loading)
    }

    @Test
    func theMessageAndTheNoteMentionEarlierVersions() throws {
        let content = try content(versions: loaded())

        #expect(content.message.key == """
        Choose the platforms and, if you want, an earlier version. CleanerXcode downloads one at a time. \
        Each one is several GB.
        """)
        #expect(RuntimeDownloadSheetContent.earlierVersionNote.key == """
        Earlier versions help you test on older systems. If Xcode doesn't accept a version, the download \
        fails without downloading anything.
        """)
        #expect(RuntimeDownloadSheetContent.versionMenuLabel(for: .iOS) == String(localized: "\("iOS") version"))
    }

    /// B4: reopening after a real "unavailable" result (F4) reads as loading from the first frame.
    @Test
    func reopeningAfterUnavailableVersionsIsLoadingFromTheFirstFrame() async throws {
        let unavailable = try RuntimeVersionsSnapshot(sdkVersions: loaded().sdkVersions, catalog: nil)
        let model = RuntimeVersionsModel(source: RuntimeVersionSourceStub(unavailable))

        await model.load()

        let closed = try content(versions: model.snapshot, isLoading: model.isLoading)

        model.beginLoading()

        let reopened = try content(versions: model.snapshot, isLoading: model.isLoading)

        #expect(closed.versionsNote == .unavailable)
        #expect(reopened.versionsNote == .loading)
        #expect(reopened.rows[0].options.map(\.title) == [String(localized: "\("27.2") (Xcode)")])
    }

    // MARK: - Private Methods

    private func version(_ text: String) throws -> RuntimeBuildVersion {
        try #require(RuntimeBuildVersion(text))
    }

    private func content(
        choice: RuntimeDownloadChoice = RuntimeDownloadChoice(),
        versions: RuntimeVersionsSnapshot?,
        isLoading: Bool = false
    ) throws -> RuntimeDownloadSheetContent {
        RuntimeDownloadSheetContent(
            choice: choice,
            runtimes: installed,
            versions: versions,
            isLoadingVersions: isLoading
        )
    }

    /// Xcode 27.2 and the catalog of the fixture as read on Apple silicon.
    private func loaded() throws -> RuntimeVersionsSnapshot {
        let catalog = try RuntimeCatalogParser.catalog(
            from: SimulatorRuntimeIndexFixture.data(),
            hostArchitecture: "arm64"
        )
        let version = try #require(RuntimeBuildVersion("27.2"))

        return RuntimeVersionsSnapshot(
            sdkVersions: Dictionary(uniqueKeysWithValues: RuntimePlatform.allCases.map { ($0, version) }),
            catalog: catalog.entries
        )
    }

    private func runtime(_ runtimeIdentifier: String, version: String) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: UUID().uuidString,
            runtimeIdentifier: runtimeIdentifier,
            version: version,
            build: "24A1",
            platformIdentifier: "com.apple.platform.iphonesimulator",
            sizeBytes: 0,
            lastUsedAt: nil,
            isDeletable: true,
            state: "Ready",
            kind: "Patchable Cryptex Disk Image"
        )
    }

}
