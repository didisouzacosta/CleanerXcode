//
//  RuntimeVersionOptionsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The versions each platform of the "Download runtimes" sheet offers (C35, R3, R11, AC4, AC13): the
/// selected Xcode's version first, then the earlier ones of the catalog, never a newer one nor one
/// already installed.
struct RuntimeVersionOptionsTests {

    // MARK: - Private Properties

    private let prefix = "com.apple.CoreSimulator.SimRuntime."

    // MARK: - Public Methods

    @Test
    func xcodesVersionFirstThenTheEarlierOnesNotInstalled() throws {
        let snapshot = try snapshot(sdks: [.iOS: "27.2"])
        let installed = [runtime(prefix + "iOS-26-5", version: "26.5", platform: "iphonesimulator")]

        let options = RuntimeVersionOptions.options(for: .iOS, snapshot: snapshot, installed: installed)

        #expect(options.map(\.version?.rawValue) == [nil, "27.1", "26.1", "26.0"])
        #expect(options.map(\.title) == [String(localized: "\("27.2") (Xcode)"), "27.1", "26.1", "26.0"])
        #expect(options.map(\.sizeBytes) == [8_321_588_736, 7_851_823_104, 8_321_575_375, 7_986_028_446])
        #expect(options.first?.id == "xcode")
        #expect(options.dropFirst().map(\.id) == ["27.1", "26.1", "26.0"])
    }

    /// AC13: nothing newer than the selected Xcode.
    @Test
    func nothingNewerThanXcode() throws {
        let options = try RuntimeVersionOptions.options(
            for: .iOS,
            snapshot: snapshot(sdks: [.iOS: "26.5"]),
            installed: []
        )

        #expect(options.map(\.version?.rawValue) == [nil, "26.1", "26.0"])
        #expect(options.first?.title == String(localized: "\("26.5") (Xcode)"))
        #expect(options.first?.sizeBytes == 8_522_901_969)
    }

    @Test
    func withoutTheSDKVersionOnlyXcodesVersion() throws {
        let options = try RuntimeVersionOptions.options(
            for: .iOS,
            snapshot: snapshot(sdks: [.tvOS: "27.2"]),
            installed: []
        )

        #expect(options == [RuntimeVersionOption(
            version: nil,
            title: String(localized: "Xcode version"),
            sizeBytes: nil
        )])
    }

    @Test
    func whileLoadingOnlyXcodesVersion() {
        let options = RuntimeVersionOptions.options(for: .watchOS, snapshot: nil, installed: [])

        #expect(options == [RuntimeVersionOption(
            version: nil,
            title: String(localized: "Xcode version"),
            sizeBytes: nil
        )])
    }

    /// R6: without the catalog the Xcode version keeps its number, without a size.
    @Test
    func withoutTheCatalogOnlyXcodesVersionWithoutASize() throws {
        let version = try #require(RuntimeBuildVersion("27.2"))
        let snapshot = RuntimeVersionsSnapshot(sdkVersions: [.iOS: version], catalog: nil)

        let options = RuntimeVersionOptions.options(for: .iOS, snapshot: snapshot, installed: [])

        #expect(options == [RuntimeVersionOption(
            version: nil,
            title: String(localized: "\("27.2") (Xcode)"),
            sizeBytes: nil
        )])
    }

    /// The catalog has no tvOS 27.3: the Xcode version has no size, the earlier one keeps its own.
    @Test
    func aXcodeVersionMissingFromTheCatalogHasNoSize() throws {
        let options = try RuntimeVersionOptions.options(
            for: .tvOS,
            snapshot: snapshot(sdks: [.tvOS: "27.3"]),
            installed: []
        )

        #expect(options.map(\.version?.rawValue) == [nil, "27.2"])
        #expect(options.map(\.sizeBytes) == [nil, 3_758_154_240])
    }

    /// The same number written differently is the same version; another platform's runtime counts
    /// for nothing.
    @Test
    func installedVersionsCompareAsNumbersOnTheirOwnPlatform() throws {
        let installed = [
            runtime(prefix + "xrOS-26-4-1", version: "26.4.1", platform: "xrsimulator"),
            runtime(prefix + "iOS-26-0", version: "26.0.0", platform: "iphonesimulator"),
            runtime(prefix + "watchOS-26-1", version: "26.1", platform: "watchsimulator"),
        ]
        let snapshot = try snapshot(sdks: [.iOS: "27.2", .visionOS: "27.2"])

        let iOS = RuntimeVersionOptions.options(for: .iOS, snapshot: snapshot, installed: installed)
        let visionOS = RuntimeVersionOptions.options(for: .visionOS, snapshot: snapshot, installed: installed)

        #expect(iOS.map(\.version?.rawValue) == [nil, "27.1", "26.5", "26.1"])
        #expect(visionOS.map(\.version?.rawValue) == [nil])
    }

    /// The menu shows the size after the version, with the system's file size format.
    @Test
    func theLabelAddsTheSize() throws {
        let version = try #require(RuntimeBuildVersion("26.5"))
        let withSize = RuntimeVersionOption(version: version, title: "26.5", sizeBytes: 8_522_901_969)
        let withoutSize = RuntimeVersionOption(version: nil, title: "27.2 (Xcode)", sizeBytes: nil)

        #expect(withSize.label == "26.5 · \(Int64(8_522_901_969).formatted(.byteCount(style: .file)))")
        #expect(withoutSize.label == "27.2 (Xcode)")
    }

    // MARK: - Private Methods

    /// The catalog of the fixture as read on Apple silicon.
    private func snapshot(sdks: [RuntimePlatform: String]) throws -> RuntimeVersionsSnapshot {
        let catalog = try RuntimeCatalogParser.catalog(
            from: SimulatorRuntimeIndexFixture.data(),
            hostArchitecture: "arm64"
        )

        return RuntimeVersionsSnapshot(
            sdkVersions: sdks.compactMapValues(RuntimeBuildVersion.init),
            catalog: catalog.entries
        )
    }

    private func runtime(_ runtimeIdentifier: String, version: String, platform: String) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: UUID().uuidString,
            runtimeIdentifier: runtimeIdentifier,
            version: version,
            build: "23A1",
            platformIdentifier: "com.apple.platform.\(platform)",
            sizeBytes: 0,
            lastUsedAt: nil,
            isDeletable: true,
            state: "Ready",
            kind: "Patchable Cryptex Disk Image"
        )
    }

}
