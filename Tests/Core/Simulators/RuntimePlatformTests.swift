//
//  RuntimePlatformTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Testing
@testable import CleanerXcode

/// Which installed runtimes belong to each platform of the "Download runtimes" sheet (C30, A1).
struct RuntimePlatformTests {

    // MARK: - Public Methods

    @Test
    func eachPlatformHasItsSimulatorPlatformIdentifier() {
        #expect(RuntimePlatform.iOS.simulatorPlatformIdentifier == "com.apple.platform.iphonesimulator")
        #expect(RuntimePlatform.watchOS.simulatorPlatformIdentifier == "com.apple.platform.watchsimulator")
        #expect(RuntimePlatform.tvOS.simulatorPlatformIdentifier == "com.apple.platform.appletvsimulator")
        #expect(RuntimePlatform.visionOS.simulatorPlatformIdentifier == "com.apple.platform.xrsimulator")
    }

    @Test(arguments: RuntimePlatform.allCases)
    func matchesByThePlatformIdentifier(platform: RuntimePlatform) {
        let runtime = runtime(platformIdentifier: platform.simulatorPlatformIdentifier, runtimeIdentifier: "custom")

        #expect(platform.matches(runtime))

        for other in RuntimePlatform.allCases where other != platform {
            #expect(!other.matches(runtime), "\(other)")
        }
    }

    /// Without a platform identifier, the runtime identifier decides; visionOS is still `xrOS`.
    @Test
    func fallsBackToTheRuntimeIdentifierPrefix() {
        let prefix = "com.apple.CoreSimulator.SimRuntime."

        #expect(RuntimePlatform.iOS.matches(runtime(platformIdentifier: "", runtimeIdentifier: prefix + "iOS-27-2")))
        #expect(RuntimePlatform.watchOS.matches(runtime(
            platformIdentifier: "",
            runtimeIdentifier: prefix + "watchOS-27-1"
        )))
        #expect(RuntimePlatform.tvOS.matches(runtime(platformIdentifier: "", runtimeIdentifier: prefix + "tvOS-27-0")))
        #expect(RuntimePlatform.visionOS.matches(runtime(
            platformIdentifier: "",
            runtimeIdentifier: prefix + "xrOS-26-0"
        )))
        #expect(RuntimePlatform.visionOS.matches(runtime(
            platformIdentifier: "",
            runtimeIdentifier: prefix + "visionOS-27-0"
        )))
        #expect(!RuntimePlatform.iOS.matches(runtime(
            platformIdentifier: "",
            runtimeIdentifier: prefix + "watchOS-27-1"
        )))
        #expect(!RuntimePlatform.iOS.matches(runtime(platformIdentifier: "", runtimeIdentifier: "custom")))
    }

    /// A platform identifier that is present wins over the runtime identifier.
    @Test
    func thePlatformIdentifierWinsOverThePrefix() {
        let watch = runtime(
            platformIdentifier: "com.apple.platform.watchsimulator",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
        )

        #expect(RuntimePlatform.watchOS.matches(watch))
        #expect(!RuntimePlatform.iOS.matches(watch))
    }

    // MARK: - Private Methods

    private func runtime(platformIdentifier: String, runtimeIdentifier: String) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: "R",
            runtimeIdentifier: runtimeIdentifier,
            version: "27.0",
            build: "24A1",
            platformIdentifier: platformIdentifier,
            sizeBytes: 0,
            lastUsedAt: nil,
            isDeletable: true,
            state: "Ready",
            kind: "Patchable Cryptex Disk Image"
        )
    }

}
