//
//  SimulatorPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Names, symbols and summaries of the "Simulators and runtimes" page, derived from `simctl`.
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

    /// "14 simulators · 3 duplicates (7.2 GB) · 2 runtimes (15.1 GB)" once listed, or why there is
    /// nothing to show: the overview card and the page subtitle (Figma page 08). Already localized:
    /// the loaded summary joins several plurals.
    static func statusDetail(
        phase: SimulatorsPhase,
        devices: [SimulatorDevice],
        duplicateUDIDs: Set<String>,
        runtimes: [SimulatorRuntime]
    ) -> String {
        switch phase {
        case .idle, .loading:
            String(localized: "Loading the simulators…")

        case .empty:
            String(localized: "No simulators or runtimes")

        case .toolsUnavailable:
            String(localized: "Unavailable without Xcode")

        case let .failed(error):
            String(localized: "Could not list the simulators: \(String(localized: error.summary))")

        case .loaded, .deleting:
            loadedDetail(devices: devices, duplicateUDIDs: duplicateUDIDs, runtimes: runtimes)
        }
    }

    /// The sidebar badge: the duplicates, only once listed and when there are any.
    static func duplicateBadgeCount(phase: SimulatorsPhase, duplicateCount: Int) -> Int? {
        phase.showsLists && duplicateCount > 0 ? duplicateCount : nil
    }

    /// "14 · 3 duplicates (5.2 GB)" next to the "Simulators" header.
    static func devicesCaption(devices: [SimulatorDevice], duplicateUDIDs: Set<String>) -> String {
        let duplicates = devices.filter { duplicateUDIDs.contains($0.udid) }

        guard !duplicates.isEmpty else { return devices.count.formatted() }

        let duplicateCount = String(localized: "\(duplicates.count) duplicates")

        return String(localized: "\(devices.count) · \(duplicateCount) (\(format(totalBytes(of: duplicates))))")
    }

    /// "15.1 GB in 2 runtimes" next to the "Runtimes" header.
    static func runtimesCaption(runtimes: [SimulatorRuntime]) -> String {
        let bytes = format(runtimes.reduce(0) { $0 + $1.sizeBytes })

        return String(localized: "\(bytes) in \(String(localized: "\(runtimes.count) runtimes"))")
    }

    // MARK: - Private Methods

    private static func loadedDetail(
        devices: [SimulatorDevice],
        duplicateUDIDs: Set<String>,
        runtimes: [SimulatorRuntime]
    ) -> String {
        let duplicates = devices.filter { duplicateUDIDs.contains($0.udid) }
        let runtimeBytes = runtimes.reduce(0) { $0 + $1.sizeBytes }

        var parts = [String(localized: "\(devices.count) simulators")]

        if !duplicates.isEmpty {
            let duplicateCount = String(localized: "\(duplicates.count) duplicates")

            parts.append("\(duplicateCount) (\(format(totalBytes(of: duplicates))))")
        }

        parts.append("\(String(localized: "\(runtimes.count) runtimes")) (\(format(runtimeBytes)))")

        return parts.joined(separator: " · ")
    }

    private static func totalBytes(of devices: [SimulatorDevice]) -> Int64 {
        devices.reduce(0) { $0 + $1.sizeBytes }
    }

    private static func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

}
