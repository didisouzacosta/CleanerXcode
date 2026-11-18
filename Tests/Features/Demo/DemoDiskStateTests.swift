//
//  DemoDiskStateTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct DemoDiskStateTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: .inert)

    // MARK: - Public Methods

    @Test
    func readsEachTargetByTheEndOfItsPath() throws {
        let state = DemoDiskState()
        let derivedData = try #require(target(of: .removeDerivedData))
        let archives = try #require(target(of: .removeArchives))

        #expect(state.size(of: derivedData) == 33_800_000_000)
        #expect(state.size(of: archives) == 4_200_000_000)
    }

    @Test
    func userDataRootDoesNotTakeTheSizeOfItsPreviewsFolder() throws {
        let state = DemoDiskState(entries: [.init(suffix: "UserData/Previews", bytes: 10)])
        let userData = try #require(target(of: .removeXcodeUserData))

        #expect(state.size(of: userData) == 0)
    }

    @Test
    func unknownRootMeasuresZero() {
        let state = DemoDiskState()
        let unknown = CleanupTarget(root: URL(filePath: "/var/empty/CleanerXcode-inert/home/Elsewhere"))

        #expect(state.size(of: unknown) == 0)
        #expect(state.order(of: unknown) == nil)
    }

    @Test
    func cleaningATargetFreesItsBytesOnce() throws {
        let state = DemoDiskState()
        let archives = try #require(target(of: .removeArchives))

        #expect(state.clean(archives) == 4_200_000_000)
        #expect(state.size(of: archives) == 0)
        #expect(state.clean(archives) == 0)
    }

    @Test
    func cleanedFolderGrowsBackItsLeftover() throws {
        let state = DemoDiskState()
        let derivedData = try #require(target(of: .removeDerivedData))

        #expect(state.clean(derivedData) == 33_800_000_000)
        #expect(state.size(of: derivedData) == 12_000_000)
    }

    /// The storyboard on Figma page "09 · Demo": 87.7 GB found, and after the cleanup 12 MB of Xcode
    /// and 6 MB of simulators.
    @Test
    func recordingMatchesTheStoryboardTotals() {
        let state = DemoDiskState()
        let targets = catalog.categories.flatMap(\.targets)
        let found = targets.reduce(0) { $0 + state.size(of: $1) } + DemoSimulatorManager.unavailableBytes

        for target in targets {
            _ = state.clean(target)
        }

        let leftover = targets.reduce(0) { $0 + state.size(of: $1) }

        #expect(found == 87_700_000_000)
        #expect(DemoSimulatorManager.unavailableBytes == 1_600_000_000)
        #expect(leftover == 18_000_000)
    }

    @Test
    func ordersTargetsAsTheEntriesAreListed() throws {
        let state = DemoDiskState(entries: [
            .init(suffix: "Xcode/Archives", bytes: 1),
            .init(suffix: "Xcode/DerivedData", bytes: 2),
        ])
        let derivedData = try #require(target(of: .removeDerivedData))
        let archives = try #require(target(of: .removeArchives))

        #expect(state.order(of: archives) == 0)
        #expect(state.order(of: derivedData) == 1)
    }

    @Test
    func everyRecordingEntryMatchesATargetOfTheInertCatalog() {
        let targets = catalog.categories.flatMap(\.targets)
        let state = DemoDiskState()

        for entry in DemoDiskState.recordingEntries {
            let matches = targets.filter { state.order(of: $0) == DemoDiskState.recordingEntries.firstIndex(of: entry) }

            #expect(matches.count == 1, "\(entry.suffix) should match exactly one target")
        }
    }

    // MARK: - Private Methods

    private func target(of id: CleanupCategoryID) -> CleanupTarget? {
        catalog.categories.first { $0.id == id }?.targets.first
    }

}
