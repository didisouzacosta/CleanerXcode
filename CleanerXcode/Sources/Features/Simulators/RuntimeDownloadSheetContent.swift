//
//  RuntimeDownloadSheetContent.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation

/// What the "Download runtimes" sheet shows (C30, A1): the four platforms in order, with what is
/// installed for each, the selection and the primary button. Each platform has a menu of versions,
/// Xcode's first (C35, R3, R4); while they load, or when they are unavailable, a note says so (R5, R6).
struct RuntimeDownloadSheetContent {

    // MARK: - Public Properties

    /// Shown with an earlier version chosen for a checked platform (R11).
    static let earlierVersionNote: LocalizedStringResource = """
    Earlier versions help you test on older systems. If Xcode doesn't accept a version, the download \
    fails without downloading anything.
    """

    let rows: [Row]
    let selectionSummary: String
    let confirmTitle: LocalizedStringResource
    let isConfirmEnabled: Bool
    let versionsNote: VersionsNote?
    let showsEarlierVersionNote: Bool

    let message: LocalizedStringResource = """
    Choose the platforms and, if you want, an earlier version. CleanerXcode downloads one at a time. \
    Each one is several GB.
    """

    // MARK: - Initializers

    /// `versions` is `nil` until the first half of the first load arrives.
    init(
        choice: RuntimeDownloadChoice,
        runtimes: [SimulatorRuntime],
        versions: RuntimeVersionsSnapshot?,
        isLoadingVersions: Bool
    ) {
        let count = choice.selected.count

        rows = RuntimePlatform.allCases.map { platform in
            let options = RuntimeVersionOptions.options(for: platform, snapshot: versions, installed: runtimes)
            let chosen = options.first { $0.version != nil && $0.version == choice.versions[platform] }

            return Row(
                platform: platform,
                systemImage: Self.systemImage(for: platform),
                installedDetail: Self.installedDetail(of: platform, in: runtimes),
                isSelected: choice.selected.contains(platform),
                options: options,
                selectedOption: chosen ?? options[0]
            )
        }

        selectionSummary = count > 0 ? String(localized: "\(count) selected") : String(localized: "None selected")
        confirmTitle = count > 0 ? "Download \(count) runtimes" : "Download runtimes"
        isConfirmEnabled = count > 0
        showsEarlierVersionNote = rows.contains { $0.isSelected && $0.selectedOption.version != nil }

        // The sheet always loads when it opens: never loaded yet is loading, even in the first frame,
        // before the load has started (B1).
        if isLoadingVersions || versions == nil {
            versionsNote = .loading
        } else if versions?.isComplete != true {
            versionsNote = .unavailable
        } else {
            versionsNote = nil
        }
    }

    // MARK: - Public Methods

    /// What VoiceOver reads for a platform's menu: "iOS version".
    static func versionMenuLabel(for platform: RuntimePlatform) -> String {
        String(localized: "\(platform.rawValue) version")
    }

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
        /// Never empty: Xcode's version comes first.
        let options: [RuntimeVersionOption]
        /// The chosen version when the menu offers it, otherwise Xcode's.
        let selectedOption: RuntimeVersionOption

        var id: RuntimePlatform {
            platform
        }

    }

    /// Below the list of platforms.
    enum VersionsNote: Equatable {

        // MARK: - Cases

        case loading
        /// With "Try again".
        case unavailable

        // MARK: - Public Properties

        var text: LocalizedStringResource {
            switch self {
            case .loading:
                "Loading earlier versions…"

            case .unavailable:
                """
                Earlier versions are unavailable right now. You can still download the version that matches \
                Xcode.
                """
            }
        }

    }

}
