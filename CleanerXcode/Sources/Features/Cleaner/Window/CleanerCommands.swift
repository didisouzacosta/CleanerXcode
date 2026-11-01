//
//  CleanerCommands.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The pages in the View menu, ⌘1 to ⌘6 (D4). Disabled without a focused window; no command
/// starts a cleanup (R39).
struct CleanerCommands: Commands {

    // MARK: - States

    @FocusedBinding(\.sidebarDestination) private var destination

    // MARK: - Public Properties

    var body: some Commands {
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

extension FocusedValues {

    /// The focused window's sidebar page, for `CleanerCommands`.
    @Entry var sidebarDestination: Binding<SidebarDestination>?

}
