//
//  DonationPromptPolicy.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// When the success suggests a donation (C31): on every `interval`-th successful cleanup, counted
/// across launches, and never before the first one. The interval lives only here.
nonisolated struct DonationPromptPolicy: Equatable, Sendable {

    // MARK: - Public Properties

    var interval = 5

    // MARK: - Public Methods

    func shouldPrompt(afterSuccessfulCleanups count: Int) -> Bool {
        count > 0 && count.isMultiple(of: interval)
    }

}
