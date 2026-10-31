//
//  SimulatorPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Names and symbols of the Simulators section, derived from the `simctl` identifiers.
enum SimulatorPresentation {

    // MARK: - Private Properties

    private static let runtimePrefix = "com.apple.CoreSimulator.SimRuntime."

    // MARK: - Public Methods

    /// `com.apple.CoreSimulator.SimRuntime.iOS-27-2` → `iOS 27.2`; anything else is kept as is.
    static func runtimeName(_ identifier: String) -> String {
        guard identifier.hasPrefix(runtimePrefix) else { return identifier }

        let parts = identifier.dropFirst(runtimePrefix.count).split(separator: "-")

        guard let platform = parts.first, parts.count > 1 else { return identifier }

        return "\(platform) \(parts.dropFirst().joined(separator: "."))"
    }

    static func systemImage(forDeviceType identifier: String) -> String {
        if identifier.contains("iPad") {
            "ipad"
        } else if identifier.contains("Watch") {
            "applewatch"
        } else if identifier.contains("TV") {
            "appletv"
        } else if identifier.contains("Vision") {
            "visionpro"
        } else {
            "iphone"
        }
    }

}
