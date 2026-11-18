//
//  RuntimeDownloadSheetContentTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import AppKit
import Foundation
import Testing
@testable import CleanerXcode

/// The "Download runtimes" sheet (C30, A1): the four platforms in order, what is installed for each,
/// and a primary button that needs at least one selected platform.
struct RuntimeDownloadSheetContentTests {

    // MARK: - Private Properties

    private let prefix = "com.apple.CoreSimulator.SimRuntime."

    // MARK: - Public Methods

    @Test
    func listsTheFourPlatformsInOrderWithTheirSymbols() {
        let content = RuntimeDownloadSheetContent(
            choice: RuntimeDownloadChoice(),
            runtimes: [],
            versions: nil,
            isLoadingVersions: false
        )

        #expect(content.rows.map(\.platform) == [.iOS, .watchOS, .tvOS, .visionOS])
        #expect(content.rows.map(\.systemImage) == ["iphone", "applewatch", "appletv", "visionpro"])
        #expect(content.rows.allSatisfy { !$0.isSelected })
        #expect(content.rows.allSatisfy { $0.installedDetail == String(localized: "No runtime installed") })
    }

    @Test
    func theSymbolsExist() {
        let content = RuntimeDownloadSheetContent(
            choice: RuntimeDownloadChoice(),
            runtimes: [],
            versions: nil,
            isLoadingVersions: false
        )

        for symbol in content.rows.map(\.systemImage) + ["arrow.down.circle"] {
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol)")
        }
    }

    /// Newest first, without repeats; visionOS runtimes are named by the platform, not `xrOS`.
    @Test
    func tellsWhatIsInstalledForEachPlatform() {
        let runtimes = [
            runtime(prefix + "iOS-27-1", version: "27.1", platform: "iphonesimulator"),
            runtime(prefix + "iOS-27-2", version: "27.2", platform: "iphonesimulator"),
            runtime(prefix + "iOS-27-2", version: "27.2", platform: "iphonesimulator"),
            runtime(prefix + "iOS-9-3", version: "9.3", platform: "iphonesimulator"),
            runtime(prefix + "xrOS-26-0", version: "26.0", platform: "xrsimulator"),
            runtime(prefix + "watchOS-11-0", version: "", platform: "watchsimulator"),
        ]

        let content = RuntimeDownloadSheetContent(
            choice: RuntimeDownloadChoice(),
            runtimes: runtimes,
            versions: nil,
            isLoadingVersions: false
        )
        let details = content.rows.map(\.installedDetail)

        #expect(details[0] == String(localized: "Installed: \("iOS 27.2, iOS 27.1, iOS 9.3")"))
        #expect(details[1] == String(localized: "Installed: \("watchOS 11.0")"))
        #expect(details[2] == String(localized: "No runtime installed"))
        #expect(details[3] == String(localized: "Installed: \("visionOS 26.0")"))
    }

    @Test
    func nothingSelectedCannotBeConfirmed() {
        let content = RuntimeDownloadSheetContent(
            choice: RuntimeDownloadChoice(),
            runtimes: [],
            versions: nil,
            isLoadingVersions: false
        )

        #expect(content.selectionSummary == String(localized: "None selected"))
        #expect(content.confirmTitle.key == "Download runtimes")
        #expect(!content.isConfirmEnabled)
    }

    @Test
    func theSelectionIsCountedAndConfirmable() {
        var choice = RuntimeDownloadChoice()

        choice.toggle(.visionOS)

        let one = RuntimeDownloadSheetContent(choice: choice, runtimes: [], versions: nil, isLoadingVersions: false)

        choice.toggle(.watchOS)

        let two = RuntimeDownloadSheetContent(choice: choice, runtimes: [], versions: nil, isLoadingVersions: false)

        #expect(one.selectionSummary == String(localized: "\(1) selected"))
        #expect(one.confirmTitle.key == "Download %lld runtimes")
        #expect(String(localized: one.confirmTitle) == String(localized: "Download \(1) runtimes"))
        #expect(one.isConfirmEnabled)
        #expect(two.selectionSummary == String(localized: "\(2) selected"))
        #expect(String(localized: two.confirmTitle) == String(localized: "Download \(2) runtimes"))
        #expect(two.rows.map(\.isSelected) == [false, true, false, true])
    }

    @Test
    func theChoiceKeepsThePlatformOrderAndTogglesOff() {
        var choice = RuntimeDownloadChoice()

        choice.toggle(.visionOS)
        choice.toggle(.iOS)
        choice.toggle(.tvOS)
        choice.toggle(.tvOS)

        #expect(choice.orderedSelection == [.iOS, .visionOS])
        #expect(choice.selected == [.iOS, .visionOS])
    }

    // MARK: - Private Methods

    private func runtime(_ runtimeIdentifier: String, version: String, platform: String) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: UUID().uuidString,
            runtimeIdentifier: runtimeIdentifier,
            version: version,
            build: "24A1",
            platformIdentifier: "com.apple.platform.\(platform)",
            sizeBytes: 0,
            lastUsedAt: nil,
            isDeletable: true,
            state: "Ready",
            kind: "Patchable Cryptex Disk Image"
        )
    }

}
