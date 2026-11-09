//
//  VersionFileUpdater.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import AppKit

/// The update path of a build without Sparkle (C42), as before the 1.0: `version.json` names the
/// newest version and its download, which opens in the browser. A newer build of the same version
/// counts as newer.
final class VersionFileUpdater: SoftwareUpdating {

    // MARK: - Public Properties

    /// Read by the composition tests.
    let checker: any VersionChecking
    let supportsUserChecks = false
    let automaticallyChecksForUpdates = false

    // MARK: - Private Properties

    private let current: SemanticVersion?
    private let open: (URL) -> Void

    private var downloadURL: URL?

    // MARK: - Initializers

    init(
        currentVersion: String,
        currentBuild: String,
        checker: any VersionChecking,
        open: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.current = SemanticVersion(currentVersion, build: currentBuild)
        self.checker = checker
        self.open = open
    }

    // MARK: - Public Methods

    func newerVersion() async throws -> String? {
        let latest = try await checker.latestVersion()

        guard
            let current, let remote = SemanticVersion(latest.version, build: latest.build),
            remote > current
        else {
            downloadURL = nil
            return nil
        }

        downloadURL = latest.downloadURL

        return latest.version
    }

    func presentUpdate() {
        guard let downloadURL else { return }

        open(downloadURL)
    }

    func checkForUpdates() {}

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {}

}
