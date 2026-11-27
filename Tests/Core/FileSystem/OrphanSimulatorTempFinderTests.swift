//
//  OrphanSimulatorTempFinderTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct OrphanSimulatorTempFinderTests {

    // MARK: - Private Properties

    private let known = "AAAA0000-0000-0000-0000-000000000001"
    private let gone = "BBBB0000-0000-0000-0000-000000000002"
    private let base = URL(filePath: "/private/var/tmp", directoryHint: .isDirectory)

    // MARK: - Public Methods

    @Test
    func onlyFoldersOfSimulatorsMissingFromEverySetAreOrphans() {
        let finder = OrphanSimulatorTempFinder(knownUDIDs: [known])

        #expect(finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.\(gone)")))
        #expect(!finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.\(known)")))
        #expect(!finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.\(known.lowercased())")))
        #expect(!finder.isOrphan(base.appending(path: "com.apple.launchd.zvq9FBiOXN")))
        #expect(!finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.")))
        #expect(!finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.not-a-udid")))
        #expect(!finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.\(gone).old")))
        #expect(!finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.\(gone)x")))
    }

    @Test
    func comparesTheKnownUDIDsWithoutCase() {
        let finder = OrphanSimulatorTempFinder(knownUDIDs: [known.lowercased()])

        #expect(!finder.isOrphan(base.appending(path: "com.apple.CoreSimulator.SimDevice.\(known)")))
    }

    @Test
    func collectsTheUDIDsOfEverySet() async throws {
        let xcTest = DeviceSet.custom(URL(filePath: "/Users/qa/Library/Developer/XCTestDevices"))
        let simulators = SimulatorManagerStub(devices: [.default: [known], xcTest: [gone]])

        let udids = try await OrphanSimulatorTempFinder.knownUDIDs(from: simulators, in: [.default, xcTest])

        #expect(udids == [known, gone])
    }

    /// Without the full list nothing can be called an orphan.
    @Test
    func failsWhenAnySetCannotBeListed() async throws {
        let xcTest = DeviceSet.custom(URL(filePath: "/Users/qa/Library/Developer/XCTestDevices"))
        let simulators = SimulatorManagerStub(devices: [.default: [known]], failingSets: [xcTest: .toolUnavailable])

        await #expect(throws: CleanupError.toolUnavailable) {
            try await OrphanSimulatorTempFinder.knownUDIDs(from: simulators, in: [.default, xcTest])
        }
    }

    @Test
    func everySetMeansTheDefaultSetPlusTheAuxiliarySetsThatExist() throws {
        let fixture = try TemporaryDirectoryFixture()
        let locations = try CleanupLocations(
            home: fixture.makeDirectory("home"),
            userTemporary: fixture.makeDirectory("T"),
            systemTemporary: fixture.makeDirectory("tmp"),
            varTemporary: fixture.makeDirectory("var/tmp")
        )
        let xcTest = try fixture.makeDirectory("home/Library/Developer/XCTestDevices")
        let previews = try fixture.makeDirectory("home/Library/Developer/Xcode/UserData/Previews/Simulator Devices")

        let sets = DeviceSet.all(in: locations)

        #expect(sets == [.default, .custom(xcTest), .custom(previews)])
        #expect(DeviceSet.auxiliarySetPaths == [
            "Library/Developer/XCTestDevices",
            "Library/Developer/Xcode/UserData/Previews/Simulator Devices",
            "Library/Developer/Xcode/UserData/IB Support/Simulator Devices",
            "Library/Developer/XCPGDevices",
        ])
    }

}
