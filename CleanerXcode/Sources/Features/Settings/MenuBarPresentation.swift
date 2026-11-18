//
//  MenuBarPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The menu bar item (R14): the size next to the icon, and what closing the last window does.
enum MenuBarPresentation {

    // MARK: - Public Methods

    /// Nothing until the first measurement ends; "Cleaning" while a cleanup runs.
    static func label(phase: CleanerPhase, totalBytes: Int64, showsSize: Bool) -> Label? {
        guard showsSize else { return nil }

        switch phase {
        case .measuring(first: true): return nil
        case .cleaning, .cancelling: return .cleaning
        default: return .size(totalBytes)
        }
    }

    /// Cleaning and retrying wait while simulators or a runtime are being deleted (C21).
    static func isEnabled(_ kind: HeroContent.Action.Kind, isDeletingSimulators: Bool) -> Bool {
        switch kind {
        case .clean, .retry: !isDeletingSimulators
        default: true
        }
    }

    /// A plan waiting for a confirmation needs the main window, which shows it; the panel never
    /// asks on its own.
    static func needsMainWindow(after phase: CleanerPhase) -> Bool {
        if case .confirming = phase {
            true
        } else {
            false
        }
    }

    /// With the menu bar item on, closing the window keeps the app running.
    static func quitsAfterLastWindowClosed(showsMenuBarExtra: Bool) -> Bool {
        !showsMenuBarExtra
    }

    /// Why the main action waits: a simulator deletion blocks an otherwise enabled Clean or
    /// retry; a plan that needs a confirmation goes to the window; otherwise the usual detail.
    static func panelDetail(
        action: HeroContent.Action.Kind?,
        isEnabled: Bool,
        isDeletingSimulators: Bool,
        reviewsInWindow: Bool
    ) -> PanelDetail {
        if let action, isEnabled, !Self.isEnabled(action, isDeletingSimulators: isDeletingSimulators) {
            return .waitForSimulators
        }

        return reviewsInWindow ? .reviewInWindow : .content
    }

    /// The panel is narrower than the window: "Cleaning · 3 of 5" instead of the window's longer
    /// eyebrow; `nil` keeps the window's.
    static func eyebrow(phase: CleanerPhase) -> LocalizedStringResource? {
        guard case let .cleaning(progress) = phase else { return nil }

        return "Cleaning · \(progress.startedCategories) of \(progress.totalCategories)"
    }

    /// A total waiting to be cleaned needs no detail in the panel (Figma page 05).
    static func showsDetail(phase: CleanerPhase, detail: PanelDetail) -> Bool {
        detail != .content || phase != .ready
    }

    /// The link under the action: the details of a failed run, or the main window.
    static func link(for actions: [HeroContent.Action.Kind]) -> Link {
        actions.contains(.toggleDetails) || actions.contains(.openPrivacySettings) ? .seeDetails : .openApp
    }

    /// The failures' details live in the main window, and so does the support sheet (C31).
    static func opensMainWindow(for kind: HeroContent.Action.Kind) -> Bool {
        switch kind {
        case .toggleDetails, .supportProject: true
        case .clean, .cancel, .dismiss, .retry, .openPrivacySettings: false
        }
    }

    /// The text button under the main action: "Close" next to the donation suggestion (C31).
    static func textAction(in actions: [HeroContent.Action]) -> HeroContent.Action? {
        actions.dropFirst().first { $0.style == .plain }
    }

    // MARK: - Nested Types

    /// Why the plan waits for the main window: the riskiest kind it holds, or an open app.
    enum ReviewNote: Equatable {

        // MARK: - Cases

        case dangerous
        case attention
        case appsOpen

        // MARK: - Public Properties

        var text: LocalizedStringResource {
            switch self {
            case .dangerous: "Dangerous items are selected. The confirmation opens in the main window."
            case .attention: "Items that need attention are selected. The confirmation opens in the main window."
            case .appsOpen: "Some apps are open. The confirmation opens in the main window."
            }
        }

        // MARK: - Initializers

        init(risks: [RiskLevel]) {
            if risks.contains(.dangerous) {
                self = .dangerous
            } else if risks.contains(.attention) {
                self = .attention
            } else {
                self = .appsOpen
            }
        }

    }

    enum Link: Equatable {
        case openApp
        case seeDetails
    }

    enum PanelDetail: Equatable {
        case content
        case waitForSimulators
        case reviewInWindow
    }

    enum Label: Equatable {
        case size(Int64)
        case cleaning
    }

}
