//
//  SimulatorPresentationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct SimulatorPresentationTests {

    // MARK: - Public Methods

    @Test
    func turnsARuntimeIdentifierIntoItsName() {
        #expect(SimulatorPresentation.runtimeName("com.apple.CoreSimulator.SimRuntime.iOS-27-2") == "iOS 27.2")
        #expect(SimulatorPresentation.runtimeName("com.apple.CoreSimulator.SimRuntime.watchOS-11-0") == "watchOS 11.0")
        #expect(SimulatorPresentation.runtimeName("com.apple.CoreSimulator.SimRuntime.xrOS-2-1") == "xrOS 2.1")
        #expect(SimulatorPresentation.runtimeName("custom") == "custom")
        #expect(SimulatorPresentation.runtimeName("") == "")
    }

    @Test
    func picksTheSymbolOfTheDeviceType() {
        let prefix = "com.apple.CoreSimulator.SimDeviceType."

        #expect(SimulatorPresentation.systemImage(forDeviceType: prefix + "iPhone-17-Pro") == "iphone")
        #expect(SimulatorPresentation.systemImage(forDeviceType: prefix + "iPad-Pro-13-inch-M5") == "ipad")
        #expect(SimulatorPresentation.systemImage(forDeviceType: prefix + "Apple-Watch-Ultra-3-49mm") == "applewatch")
        #expect(SimulatorPresentation.systemImage(forDeviceType: prefix + "Apple-TV-4K-3rd-generation-4K") == "appletv")
        #expect(SimulatorPresentation.systemImage(forDeviceType: prefix + "Apple-Vision-Pro") == "visionpro")
        #expect(SimulatorPresentation.systemImage(forDeviceType: "") == "iphone")
    }

    /// For VoiceOver: a renamed simulator still tells what it is.
    @Test
    func turnsADeviceTypeIdentifierIntoItsName() {
        let prefix = "com.apple.CoreSimulator.SimDeviceType."

        #expect(SimulatorPresentation.deviceTypeName(prefix + "iPhone-17-Pro") == "iPhone 17 Pro")
        #expect(SimulatorPresentation.deviceTypeName(prefix + "Apple-Watch-Ultra-3-49mm") == "Apple Watch Ultra 3 49mm")
        #expect(SimulatorPresentation.deviceTypeName("custom") == "custom")
    }

    /// `simctl` reports states in English; the known ones become translated text (AC18).
    @Test
    func translatesTheKnownRuntimeStates() {
        #expect(SimulatorPresentation.runtimeStateText("Ready") == nil)
        #expect(SimulatorPresentation.runtimeStateText("") == nil)
        #expect(SimulatorPresentation.runtimeStateText("Deleting")?.key == "deleting…")
        #expect(SimulatorPresentation.runtimeStateText("Unusable")?.key == "unusable")
        #expect(
            SimulatorPresentation.runtimeStateText("Mounting")?.key == "%@",
            "Unknown states are kept as they come."
        )
    }

    @Test
    func describesTheStateOfADevice() {
        #expect(SimulatorPresentation.deviceStateText(.booted, isAvailable: true).key == "on")
        #expect(SimulatorPresentation.deviceStateText(.shutdown, isAvailable: true).key == "off")
        #expect(SimulatorPresentation.deviceStateText(.shutdown, isAvailable: false).key == "unavailable")
        #expect(SimulatorPresentation.deviceStateText(.other("Booting"), isAvailable: true).key == "booting")
        #expect(SimulatorPresentation.deviceStateText(.other("Shutting Down"), isAvailable: true)
            .key == "shutting down")
        #expect(SimulatorPresentation.deviceStateText(.other("Creating"), isAvailable: true).key == "creating")
        #expect(SimulatorPresentation.deviceStateText(.other("Odd"), isAvailable: true).key == "%@")
    }

    /// The type only joins the VoiceOver label when the name no longer tells it.
    @Test
    func speaksTheTypeOnlyForRenamedSimulators() {
        let type = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"

        #expect(SimulatorPresentation.spokenType(name: "iPhone 17 Pro", deviceType: type) == nil)
        #expect(SimulatorPresentation.spokenType(name: "My test phone", deviceType: type) == "iPhone 17 Pro")
    }

    /// "14 simulators · 3 duplicates (7.2 GB) · 2 runtimes (15.1 GB)" once listed, or why there
    /// is nothing to show: the overview card and the page subtitle (Figma page 08).
    @Test
    func describesTheStatusOfTheLists() {
        let devices = [device("A", bytes: 1_000), device("B", bytes: 2_000), device("C", bytes: 4_000)]
        let runtimes = [runtime("R1", bytes: 7_000), runtime("R2", bytes: 8_000)]
        let loaded = [
            String(localized: "\(3) simulators"),
            "\(String(localized: "\(2) duplicates")) (\(format(6_000)))",
            "\(String(localized: "\(2) runtimes")) (\(format(15_000)))",
        ].joined(separator: " · ")

        #expect(status(.loaded, devices, duplicates: ["B", "C"], runtimes) == loaded)
        #expect(status(.deleting(["B"]), devices, duplicates: ["B", "C"], runtimes) == loaded)
        #expect(
            status(.loaded, devices, duplicates: [], runtimes)
                == "\(String(localized: "\(3) simulators")) · \(String(localized: "\(2) runtimes")) (\(format(15_000)))"
        )
        #expect(status(.idle) == String(localized: "Loading the simulators…"))
        #expect(status(.loading) == String(localized: "Loading the simulators…"))
        #expect(status(.empty) == String(localized: "No simulators or runtimes"))
        #expect(status(.toolsUnavailable) == String(localized: "Unavailable without Xcode"))
        #expect(
            status(.failed(.timedOut))
                ==
                String(
                    localized: "Could not list the simulators: \(String(localized: CleanupError.timedOut.summary))"
                )
        )
    }

    /// The sidebar badge counts the duplicates, only once listed and when there are any.
    @Test
    func theBadgeCountsTheDuplicatesOfTheLoadedList() {
        #expect(SimulatorPresentation.duplicateBadgeCount(phase: .loaded, duplicateCount: 3) == 3)
        #expect(SimulatorPresentation.duplicateBadgeCount(phase: .deleting(["A"]), duplicateCount: 3) == 3)
        #expect(SimulatorPresentation.duplicateBadgeCount(phase: .loaded, duplicateCount: 0) == nil)
        #expect(SimulatorPresentation.duplicateBadgeCount(phase: .loading, duplicateCount: 3) == nil)
        #expect(SimulatorPresentation.duplicateBadgeCount(phase: .idle, duplicateCount: 3) == nil)
    }

    /// "14 · 3 duplicates (5.2 GB)" and "15.1 GB in 2 runtimes" next to the page's headers.
    @Test
    func captionsTheTwoLists() {
        let devices = [device("A", bytes: 1_000), device("B", bytes: 2_000)]

        #expect(
            SimulatorPresentation.devicesCaption(devices: devices, duplicateUDIDs: ["B"])
                == String(localized: "\(2) · \(String(localized: "\(1) duplicates")) (\(format(2_000)))")
        )
        #expect(SimulatorPresentation.devicesCaption(devices: devices, duplicateUDIDs: []) == 2.formatted())
        #expect(
            SimulatorPresentation.runtimesCaption(runtimes: [runtime("R1", bytes: 7_000)])
                == String(localized: "\(format(7_000)) in \(String(localized: "\(1) runtimes"))")
        )
    }

    // MARK: - Private Methods

    private func status(
        _ phase: SimulatorsPhase,
        _ devices: [SimulatorDevice] = [],
        duplicates: Set<String> = [],
        _ runtimes: [SimulatorRuntime] = []
    ) -> String {
        SimulatorPresentation.statusDetail(
            phase: phase,
            devices: devices,
            duplicateUDIDs: duplicates,
            runtimes: runtimes
        )
    }

    private func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    private func device(_ udid: String, bytes: Int64) -> SimulatorDevice {
        SimulatorDevice(
            udid: udid,
            name: "iPhone 17 Pro",
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-2",
            state: .shutdown,
            isAvailable: true,
            lastUsedAt: nil,
            sizeBytes: bytes
        )
    }

    private func runtime(_ identifier: String, bytes: Int64) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: identifier,
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-2",
            version: "27",
            build: "24A1",
            platformIdentifier: "com.apple.platform.iphonesimulator",
            sizeBytes: bytes,
            lastUsedAt: nil,
            isDeletable: true,
            state: "Ready",
            kind: "Patchable Cryptex Disk Image"
        )
    }

}
