//
//  SimulatorPresentationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

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

}
