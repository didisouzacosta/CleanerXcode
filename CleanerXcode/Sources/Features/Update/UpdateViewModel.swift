//
//  UpdateViewModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Observation

/// The "Atualizar" button of the footer and the About tab (R16, R17). Only a newer version is
/// offered; a failed check is never shown and leaves a breadcrumb.
@Observable
final class UpdateViewModel {

    // MARK: - Public Properties

    /// Read by the composition tests.
    let checker: any VersionChecking

    private(set) var availableUpdate: Version?

    // MARK: - Private Properties

    private let current: SemanticVersion?
    private let analytics: any Analytics
    private let errorReporter: any ErrorReporting

    // MARK: - Initializers

    init(
        currentVersion: String,
        currentBuild: String,
        checker: any VersionChecking,
        analytics: any Analytics,
        errorReporter: any ErrorReporting
    ) {
        self.current = SemanticVersion(currentVersion, build: currentBuild)
        self.checker = checker
        self.analytics = analytics
        self.errorReporter = errorReporter
    }

    // MARK: - Private Static Methods

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    // MARK: - Public Methods

    func check() async {
        do {
            let latest = try await checker.latestVersion()

            guard
                let current, let remote = SemanticVersion(latest.version, build: latest.build),
                remote > current
            else {
                availableUpdate = nil
                return
            }

            availableUpdate = latest
        } catch {
            // Closing the window cancels the check: an expected end, not a failure.
            guard !Self.isCancellation(error) else { return }

            errorReporter.breadcrumb(.updateCheckFailed)
        }
    }

    func logUpdateOpened() {
        analytics.log(.updateOpened)
    }

}
