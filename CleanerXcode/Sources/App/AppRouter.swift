//
//  AppRouter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Observation

/// The page the main window should show when "Settings…" (⌘,) or the panel's gear opens it (C40).
/// The window keeps its own selection; it takes the pending page when it appears or when a new
/// one is asked for.
@Observable
final class AppRouter {

    // MARK: - Public Properties

    private(set) var pendingDestination: SidebarDestination?

    // MARK: - Public Methods

    func show(_ destination: SidebarDestination) {
        pendingDestination = destination
    }

    /// Returns the pending page once.
    func takePendingDestination() -> SidebarDestination? {
        let destination = pendingDestination

        pendingDestination = nil

        return destination
    }

}
