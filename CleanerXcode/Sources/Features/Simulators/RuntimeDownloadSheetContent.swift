//
//  RuntimeDownloadSheetContent.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation

/// What the "Download runtimes" sheet shows (C30, A1): the four platforms in order, with what is
/// installed for each, the selection and the primary button.
struct RuntimeDownloadSheetContent {

    // MARK: - Public Properties

    let rows: [Row]
    let selectionSummary: String
    let confirmTitle: LocalizedStringResource
    let isConfirmEnabled: Bool

    // MARK: - Initializers

    init(choice: RuntimeDownloadChoice, runtimes: [SimulatorRuntime]) {
        let count = choice.selected.count

        rows = RuntimePlatform.allCases.map { platform in
            Row(
                platform: platform,
                systemImage: Self.systemImage(for: platform),
                installedDetail: Self.installedDetail(of: platform, in: runtimes),
                isSelected: choice.selected.contains(platform)
            )
        }

        selectionSummary = count > 0 ? String(localized: "\(count) selected") : String(localized: "None selected")
        confirmTitle = count > 0 ? "Download \(count) runtimes" : "Download runtimes"
        isConfirmEnabled = count > 0
    }

    // MARK: - Public Methods

    /// The same symbols as the simulators of each platform on the page.
    static func systemImage(for platform: RuntimePlatform) -> String {
        switch platform {
        case .iOS: "iphone"
        case .watchOS: "applewatch"
        case .tvOS: "appletv"
        case .visionOS: "visionpro"
        }
    }

    /// "iOS 27.2, iOS 27.1": newest first, without repeats, named by the platform ("visionOS 26.0",
    /// not "xrOS 26.0") unless the version is missing (Q10).
    static func installedNames(of platform: RuntimePlatform, in runtimes: [SimulatorRuntime]) -> [String] {
        let names = runtimes
            .filter(platform.matches)
            .map { runtime in
                runtime.version.isEmpty
                    ? SimulatorPresentation.runtimeName(runtime.runtimeIdentifier)
                    : "\(platform.rawValue) \(runtime.version)"
            }
            .sorted { $0.compare($1, options: .numeric) == .orderedDescending }

        var seen: Set<String> = []

        return names.filter { seen.insert($0).inserted }
    }

    // MARK: - Private Methods

    private static func installedDetail(of platform: RuntimePlatform, in runtimes: [SimulatorRuntime]) -> String {
        let names = installedNames(of: platform, in: runtimes)

        guard !names.isEmpty else { return String(localized: "No runtime installed") }

        return String(localized: "Installed: \(names.joined(separator: ", "))")
    }

    // MARK: - Nested Types

    struct Row: Identifiable, Equatable {

        // MARK: - Public Properties

        let platform: RuntimePlatform
        let systemImage: String
        /// Already localized.
        let installedDetail: String
        let isSelected: Bool

        var id: RuntimePlatform {
            platform
        }

    }

}
