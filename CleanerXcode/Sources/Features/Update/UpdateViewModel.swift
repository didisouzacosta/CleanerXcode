//
//  UpdateViewModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Observation

/// The update button of the footer and the About page (R16, R17), "Check for Updates…" and the
/// automatic checks switch (C42). Only a newer version is offered; a failed check is never shown
/// and leaves a breadcrumb.
@Observable
final class UpdateViewModel {

    // MARK: - Public Properties

    /// Read by the composition tests.
    let updater: any SoftwareUpdating

    private(set) var availableVersion: String?
    private(set) var automaticallyChecksForUpdates: Bool

    var canCheckForUpdates: Bool {
        updater.supportsUserChecks
    }

    // MARK: - Private Properties

    private let analytics: any Analytics
    private let errorReporter: any ErrorReporting

    // MARK: - Initializers

    init(updater: any SoftwareUpdating, analytics: any Analytics, errorReporter: any ErrorReporting) {
        self.updater = updater
        self.analytics = analytics
        self.errorReporter = errorReporter
        self.automaticallyChecksForUpdates = updater.supportsUserChecks && updater.automaticallyChecksForUpdates
    }

    // MARK: - Private Static Methods

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    // MARK: - Public Methods

    func check() async {
        // Sparkle's own window can change the automatic checks.
        automaticallyChecksForUpdates = updater.supportsUserChecks && updater.automaticallyChecksForUpdates

        do {
            availableVersion = try await updater.newerVersion()
        } catch {
            // Closing the window, or a check that overlaps a running one, cancels it: an expected
            // end, not a failure, and the version already found stays.
            guard !Self.isCancellation(error) else { return }

            errorReporter.breadcrumb(.updateCheckFailed)
        }
    }

    func openUpdate() {
        updater.presentUpdate()
        analytics.log(.updateOpened)
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }

        updater.checkForUpdates()
    }

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
        guard canCheckForUpdates else { return }

        updater.setAutomaticallyChecksForUpdates(isOn)
        automaticallyChecksForUpdates = isOn
    }

}
