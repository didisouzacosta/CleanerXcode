//
//  ActionBarContent.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The fixed action bar at the bottom of the window (Figma page 08), adapted from `HeroContent`,
/// which stays the only source of each phase's texts and actions. The main action always comes
/// last, on the right, and only Cancel and OK (or Close) have keyboard shortcuts: nothing starts a
/// cleanup from the keyboard (R39), and supporting the project needs a click (C31).
struct ActionBarContent {

    // MARK: - Public Properties

    let symbol: HeroContent.Symbol?
    let eyebrow: LocalizedStringResource
    let amount: String
    let isAmountDimmed: Bool
    let suffix: Suffix?
    let progress: Double?
    let actions: [HeroContent.Action]

    // MARK: - Initializers

    init(hero: HeroContent, phase: CleanerPhase, isShowingDetails: Bool) {
        let isFirstMeasurement = phase == .measuring(first: true)

        symbol = hero.symbol
        eyebrow = Self.eyebrow(hero: hero, phase: phase)
        amount = isFirstMeasurement ? "—" : hero.amount
        isAmountDimmed = isFirstMeasurement || hero.isAmountDimmed
        suffix = Self.suffix(hero: hero, phase: phase)

        if case .cleaning = phase {
            progress = hero.progress
        } else {
            progress = nil
        }

        actions = Self.actions(hero.actions, isShowingDetails: isShowingDetails)
    }

    // MARK: - Private Methods

    private static func eyebrow(hero: HeroContent, phase: CleanerPhase) -> LocalizedStringResource {
        switch phase {
        case .measuring(first: true):
            "Calculating the space…"

        case let .cleaning(progress):
            "Cleaning · \(progress.startedCategories) of \(progress.totalCategories)"

        default:
            hero.eyebrow
        }
    }

    private static func suffix(hero: HeroContent, phase: CleanerPhase) -> Suffix? {
        if hero.isFreedAmount {
            return .freed
        }

        switch phase {
        case .measuring(first: false), .ready, .confirming, .nothingSelected, .nothingToClean:
            return .estimated

        default:
            return nil
        }
    }

    /// The secondary and text actions on the left, the main one last; "See details" becomes "Hide
    /// details" while they are open.
    private static func actions(_ actions: [HeroContent.Action], isShowingDetails: Bool) -> [HeroContent.Action] {
        let retitled = actions.map { action in
            guard action.kind == .toggleDetails, isShowingDetails else { return action }

            return HeroContent.Action(.toggleDetails, "Hide details", style: action.style, isEnabled: action.isEnabled)
        }

        return retitled.filter { !isMain($0) } + retitled.filter(isMain)
    }

    private static func isMain(_ action: HeroContent.Action) -> Bool {
        switch action.style {
        case .prominent, .destructive, .support: true
        case .secondary, .plain: false
        }
    }

    // MARK: - Public Methods

    /// Esc only stops a running cleanup, and Return only closes a finished report.
    func shortcut(for kind: HeroContent.Action.Kind) -> Shortcut? {
        switch kind {
        case .cancel: .cancel
        case .dismiss: .default
        case .clean, .retry, .toggleDetails, .openPrivacySettings, .supportProject: nil
        }
    }

    // MARK: - Nested Types

    /// "estimated" next to a total still to clean, "freed" next to what a run freed.
    enum Suffix: Hashable {
        case estimated
        case freed
    }

    enum Shortcut: Hashable {
        /// Esc.
        case cancel
        /// Return.
        case `default`
    }

}
