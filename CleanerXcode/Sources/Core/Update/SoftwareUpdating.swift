//
//  SoftwareUpdating.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// Where the app learns about a newer version and how it installs it (C42): Sparkle in a
/// configured Release build, `version.json` in any other build, and nothing in the test host,
/// previews and the demo.
protocol SoftwareUpdating: AnyObject {
    /// "Check for Updates…" and the automatic checks exist only with Sparkle.
    var supportsUserChecks: Bool { get }
    var automaticallyChecksForUpdates: Bool { get }

    /// The display version of a newer build, or `nil`. It never shows a window.
    func newerVersion() async throws -> String?
    /// Shows the newer version: Sparkle's update window, or the download page.
    func presentUpdate()
    /// "Check for Updates…": a check started by the user, with Sparkle's windows.
    func checkForUpdates()
    /// Only Sparkle keeps it; the other updaters ignore it.
    func setAutomaticallyChecksForUpdates(_ isOn: Bool)
}

/// For the test host, previews and the demo: never reaches the network nor shows a window.
final class InertSoftwareUpdater: SoftwareUpdating {

    // MARK: - Public Properties

    let supportsUserChecks = false
    let automaticallyChecksForUpdates = false

    // MARK: - Public Methods

    func newerVersion() -> String? {
        nil
    }

    func presentUpdate() {}

    func checkForUpdates() {}

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {}

}
