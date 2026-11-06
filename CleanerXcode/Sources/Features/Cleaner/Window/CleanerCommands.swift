//
//  CleanerCommands.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit
import SwiftUI

/// The pages in the View menu, ⌘1 to ⌘8 (D4, C40), disabled without a focused window, and
/// "Settings…" (⌘,) in the app menu, which opens the main window on General (C40). No command
/// starts a cleanup (R39).
struct CleanerCommands: Commands {

    // MARK: - States

    @FocusedBinding(\.sidebarDestination) private var destination

    // MARK: - Public Properties

    let router: AppRouter

    var body: some Commands {
        // The app has no Settings scene: its pages live in the main window's sidebar.
        CommandGroup(replacing: .appSettings) {
            SettingsCommandButton(router: router)
        }

        CommandGroup(before: .sidebar) {
            ForEach(SidebarDestination.allCases) { item in
                Button {
                    destination = item
                } label: {
                    Text(item.sidebarTitle)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(item.shortcutDigit)")), modifiers: .command)
                .disabled(destination == nil)
            }

            Divider()
        }
    }

}

/// A view inside the command, so it can read `openWindow` from the environment. It works with the
/// window closed or open.
private struct SettingsCommandButton: View {

    // MARK: - Environments

    @Environment(\.openWindow) private var openWindow

    // MARK: - Public Properties

    let router: AppRouter

    var body: some View {
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",", modifiers: .command)
    }

    // MARK: - Private Methods

    private func openSettings() {
        router.show(.general)
        openWindow(id: WindowID.main)
        NSApplication.shared.activate()
    }

}

extension FocusedValues {

    /// The focused window's sidebar page, for `CleanerCommands`.
    @Entry var sidebarDestination: Binding<SidebarDestination>?

}
