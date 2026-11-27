//
//  DuplicateSimulatorDetectorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct DuplicateSimulatorDetectorTests {

    // MARK: - Private Properties

    private let iPhone = "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"
    private let iPad = "com.apple.CoreSimulator.SimDeviceType.iPad-Air"
    private let iOS27 = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
    private let iOS26 = "com.apple.CoreSimulator.SimRuntime.iOS-26-0"

    // MARK: - Public Methods

    @Test
    func groupsDevicesWithTheSameTypeAndRuntimeAndKeepsTheMostRecentlyUsed() {
        let old = device("A", iPhone, iOS27, usedAt: 100)
        let recent = device("B", iPhone, iOS27, usedAt: 300)
        let never = device("C", iPhone, iOS27, usedAt: nil)
        let middle = device("D", iPhone, iOS27, usedAt: 200)

        let groups = DuplicateSimulatorDetector.groups(in: [old, recent, never, middle])

        #expect(groups == [DuplicateGroup(keep: recent, duplicates: [middle, old, never])])
    }

    @Test
    func neverGroupsDevicesThatDifferInTypeOrRuntime() {
        let devices = [
            device("A", iPhone, iOS27, usedAt: 1),
            device("B", iPhone, iOS26, usedAt: 2),
            device("C", iPad, iOS27, usedAt: 3),
        ]

        #expect(DuplicateSimulatorDetector.groups(in: devices).isEmpty)
    }

    /// `simctl` may omit the type; unknown types are never assumed to be the same device.
    @Test
    func neverGroupsDevicesWithoutATypeOrRuntime() {
        let devices = [
            device("A", "", iOS27, usedAt: 1),
            device("B", "", iOS27, usedAt: 2),
            device("C", iPhone, "", usedAt: 3),
            device("D", iPhone, "", usedAt: 4),
        ]

        #expect(DuplicateSimulatorDetector.groups(in: devices).isEmpty)
    }

    @Test
    func ordersGroupsAndBreaksTiesByUDIDSoTheSuggestionIsStable() {
        let first = device("B", iPhone, iOS27, usedAt: nil)
        let second = device("A", iPhone, iOS27, usedAt: nil)
        let padOld = device("D", iPad, iOS27, usedAt: 5)
        let padNew = device("C", iPad, iOS27, usedAt: 9)

        let groups = DuplicateSimulatorDetector.groups(in: [first, padOld, second, padNew])

        #expect(groups == [
            DuplicateGroup(keep: padNew, duplicates: [padOld]),
            DuplicateGroup(keep: second, duplicates: [first]),
        ])
    }

    @Test
    func suggestsEveryDuplicateForRemovalButNeverTheOneToKeep() {
        let keep = device("A", iPhone, iOS27, usedAt: 10)
        let extra = device("B", iPhone, iOS27, usedAt: 5)
        let alone = device("C", iPad, iOS27, usedAt: 1)

        #expect(DuplicateSimulatorDetector.suggestedForRemoval(in: [keep, extra, alone]) == [extra])
    }

    // MARK: - Private Methods

    private func device(_ udid: String, _ type: String, _ runtime: String, usedAt: TimeInterval?) -> SimulatorDevice {
        SimulatorDevice(
            udid: udid,
            name: "Device \(udid)",
            deviceTypeIdentifier: type,
            runtimeIdentifier: runtime,
            state: .shutdown,
            isAvailable: true,
            lastUsedAt: usedAt.map(Date.init(timeIntervalSince1970:)),
            sizeBytes: 0
        )
    }

}
