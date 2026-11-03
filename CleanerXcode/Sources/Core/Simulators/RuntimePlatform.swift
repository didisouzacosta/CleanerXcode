//
//  RuntimePlatform.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// A platform whose simulator runtime `xcodebuild -downloadPlatform` downloads. The raw value is
/// the exact argument and also the name shown, never translated.
nonisolated enum RuntimePlatform: String, CaseIterable, Sendable, Hashable {

    // MARK: - Cases

    case iOS
    case watchOS
    case tvOS
    case visionOS

    // MARK: - Public Properties

    /// `com.apple.platform.iphonesimulator`, `watchsimulator`, `appletvsimulator`, `xrsimulator`.
    var simulatorPlatformIdentifier: String {
        switch self {
        case .iOS: "com.apple.platform.iphonesimulator"
        case .watchOS: "com.apple.platform.watchsimulator"
        case .tvOS: "com.apple.platform.appletvsimulator"
        case .visionOS: "com.apple.platform.xrsimulator"
        }
    }

    // MARK: - Private Properties

    /// visionOS runtimes are still named `xrOS`.
    private var runtimeIdentifierPrefixes: [String] {
        let prefix = "com.apple.CoreSimulator.SimRuntime."

        return switch self {
        case .iOS: [prefix + "iOS-"]
        case .watchOS: [prefix + "watchOS-"]
        case .tvOS: [prefix + "tvOS-"]
        case .visionOS: [prefix + "xrOS-", prefix + "visionOS-"]
        }
    }

    // MARK: - Public Methods

    /// By `platformIdentifier`; when empty, by the runtime identifier prefix (`SimRuntime.iOS-`,
    /// `watchOS-`, `tvOS-`, `xrOS-` or `visionOS-`).
    func matches(_ runtime: SimulatorRuntime) -> Bool {
        guard runtime.platformIdentifier.isEmpty else {
            return runtime.platformIdentifier == simulatorPlatformIdentifier
        }

        return runtimeIdentifierPrefixes.contains { runtime.runtimeIdentifier.hasPrefix($0) }
    }

}
