//
//  DonationPrompt.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Observation

/// The donation suggestion (C31), owned by `CleanerViewModel`, which forwards its state and
/// intents: it counts the successful cleanups in the preferences, suggests a donation on the
/// policy's turn and opens the support sheet. Only the sheet's "Donate any amount" logs `donate`.
@Observable
final class DonationPrompt {

    // MARK: - Public Properties

    /// How many cleanups ended in success, across launches.
    static let successfulCleanupCountKey = "successful-cleanup-count"

    /// The success suggests a donation instead of OK.
    private(set) var suggestsDonation = false
    /// The "Support CleanerXcode" sheet is open.
    private(set) var isShowingSupportSheet = false

    // MARK: - Private Properties

    private let preferences: any PreferencesStoring
    private let analytics: any Analytics
    private let policy: DonationPromptPolicy

    // MARK: - Initializers

    init(preferences: any PreferencesStoring, analytics: any Analytics, policy: DonationPromptPolicy = .init()) {
        self.preferences = preferences
        self.analytics = analytics
        self.policy = policy
    }

    // MARK: - Public Methods

    /// A new cleanup closes the sheet and clears a suggestion left on screen.
    func cleanupStarted() {
        suggestsDonation = false
        isShowingSupportSheet = false
    }

    /// Only a success counts; the cleanup calls it before publishing the report, so the success
    /// never shows OK for a frame before the suggestion.
    func cleanupFinished(_ report: CleanupReport) {
        guard report.outcome == .success else { return }

        let count = recordSuccessfulCleanup()

        suggestsDonation = policy.shouldPrompt(afterSuccessfulCleanups: count)
    }

    func reportDismissed() {
        suggestsDonation = false
    }

    /// "Support the project": opens the sheet and turns the success back into the usual one, with
    /// OK. Nothing is logged until the sheet's donation.
    func supportProject() {
        guard suggestsDonation else { return }

        suggestsDonation = false
        isShowingSupportSheet = true
    }

    /// "Donate any amount", which opens the payment page: the only place the suggestion logs
    /// `donate`.
    func donateFromSupportSheet() {
        guard isShowingSupportSheet else { return }

        analytics.log(.donate)
        isShowingSupportSheet = false
    }

    /// "Not now", Esc or any other way of closing the sheet.
    func dismissSupportSheet() {
        isShowingSupportSheet = false
    }

    // MARK: - Private Methods

    /// A missing, unreadable or negative count starts from zero; it never overflows.
    private func recordSuccessfulCleanup() -> Int {
        let stored = max(preferences.integer(for: Self.successfulCleanupCountKey) ?? 0, 0)
        let count = stored < .max ? stored + 1 : stored

        preferences.set(count, for: Self.successfulCleanupCountKey)
        return count
    }

}
