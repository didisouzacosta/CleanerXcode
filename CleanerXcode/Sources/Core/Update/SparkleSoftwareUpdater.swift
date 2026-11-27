//
//  SparkleSoftwareUpdater.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Sparkle

/// Sparkle 2 (C42): reads the appcast from `SUFeedURL`, accepts only updates signed with
/// `SUPublicEDKey`, and installs them after the user confirms in Sparkle's window. Only a Release
/// build with both keys creates it, and Sparkle starts on the first use, never in a test.
///
/// The quiet check for the footer button runs through `checkForUpdateInformation()`, which shows
/// nothing; its answer arrives through the delegate and resumes the waiting call once. A check
/// that overlaps a running one ends as cancelled, so the version already found stays on screen.
/// `SUAllowsAutomaticUpdates` is off in `Info.plist`: every install asks first.
final class SparkleSoftwareUpdater: NSObject, SoftwareUpdating {

    // MARK: - Public Properties

    let supportsUserChecks = true

    var automaticallyChecksForUpdates: Bool {
        controller.updater.automaticallyChecksForUpdates
    }

    // MARK: - Private Properties

    private let errorReporter: any ErrorReporting

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private var isStarted = false
    private var pendingCheck: CheckedContinuation<String?, any Error>?

    // MARK: - Initializers

    init(errorReporter: any ErrorReporting) {
        self.errorReporter = errorReporter
    }

    // MARK: - Public Methods

    func newerVersion() async throws -> String? {
        try startIfNeeded()

        // Another check is running (a scheduled one or the user's): it reports by itself.
        guard pendingCheck == nil, !controller.updater.sessionInProgress else { throw CancellationError() }

        return try await withCheckedThrowingContinuation { continuation in
            pendingCheck = continuation
            controller.updater.checkForUpdateInformation()
        }
    }

    func presentUpdate() {
        checkForUpdates()
    }

    func checkForUpdates() {
        do {
            try startIfNeeded()
        } catch {
            errorReporter.breadcrumb(.updateCheckFailed)
            return
        }

        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
        controller.updater.automaticallyChecksForUpdates = isOn
    }

    // MARK: - Private Methods

    private func startIfNeeded() throws {
        guard !isStarted else { return }

        try controller.updater.start()
        isStarted = true
    }

    private func finishPendingCheck(with result: Result<String?, any Error>) {
        guard let pendingCheck else { return }

        self.pendingCheck = nil
        pendingCheck.resume(with: result)
    }

}

extension SparkleSoftwareUpdater: SPUUpdaterDelegate {

    // MARK: - Public Methods

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        finishPendingCheck(with: .success(item.displayVersionString))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        finishPendingCheck(with: .success(nil))
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        finishPendingCheck(with: .failure(error))
    }

    /// The end of every cycle: a check that reported nothing else still resumes its caller.
    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        finishPendingCheck(with: error.map { .failure($0) } ?? .success(nil))
    }

}
