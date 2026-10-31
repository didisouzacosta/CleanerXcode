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

}
