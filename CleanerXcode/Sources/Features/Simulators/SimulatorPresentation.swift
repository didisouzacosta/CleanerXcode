//
//  SimulatorPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Names and symbols of the Simulators section, derived from the `simctl` identifiers.
enum SimulatorPresentation {

    // MARK: - Private Properties

    private static let runtimePrefix = "com.apple.CoreSimulator.SimRuntime."
    private static let deviceTypePrefix = "com.apple.CoreSimulator.SimDeviceType."

    // MARK: - Public Methods

    /// `com.apple.CoreSimulator.SimRuntime.iOS-27-2` → `iOS 27.2`; anything else is kept as is.
    static func runtimeName(_ identifier: String) -> String {
        guard identifier.hasPrefix(runtimePrefix) else { return identifier }

        let parts = identifier.dropFirst(runtimePrefix.count).split(separator: "-")

        guard let platform = parts.first, parts.count > 1 else { return identifier }

        return "\(platform) \(parts.dropFirst().joined(separator: "."))"
    }

    /// `com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro` → `iPhone 17 Pro`, for VoiceOver.
    static func deviceTypeName(_ identifier: String) -> String {
        guard identifier.hasPrefix(deviceTypePrefix) else { return identifier }

        return String(identifier.dropFirst(deviceTypePrefix.count)).replacing("-", with: " ")
    }

    /// `nil` for a ready runtime; the known states of `simctl` are translated, others kept as is.
    static func runtimeStateText(_ state: String) -> LocalizedStringResource? {
        switch state {
        case "", "Ready": nil
        case "Deleting": "deleting…"
        case "Unusable": "unusable"
        default: "\(state)"
        }
    }

    /// A device that cannot run (`isAvailable == false`, such as a missing runtime) shows as
    /// unavailable; the known transient states are translated, others kept as is.
    static func deviceStateText(_ state: SimulatorDevice.State, isAvailable: Bool) -> LocalizedStringResource {
        guard isAvailable else { return "unavailable" }

        switch state {
        case .booted: return "on"
        case .shutdown: return "off"
        case .other("Booting"): return "booting"
        case .other("Shutting Down"): return "shutting down"
        case .other("Creating"): return "creating"
        case let .other(value): return "\(value)"
        }
    }

    /// For VoiceOver: the type, only when the name no longer tells it.
    static func spokenType(name: String, deviceType: String) -> String? {
        let type = deviceTypeName(deviceType)

        return type.isEmpty || type == name ? nil : type
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
