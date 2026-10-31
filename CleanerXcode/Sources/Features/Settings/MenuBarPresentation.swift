//
//  MenuBarPresentation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

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

    // MARK: - Nested Types

    enum Label: Equatable {
        case size(Int64)
        case cleaning
    }

}
