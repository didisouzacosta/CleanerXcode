//
//  CleanerToolbar.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// Refresh (⌘R), an icon with a label for VoiceOver that the system draws in glass, only on the
/// cleanup pages (C40). Settings lives in the sidebar, so the toolbar has no gear.
struct CleanerToolbar: ToolbarContent {

    // MARK: - Public Properties

    let destination: SidebarDestination
    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel

    var body: some ToolbarContent {
        if destination.showsCleanupControls {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                    .help("Measure every category again")
                    .keyboardShortcut("r")
                    .disabled(!viewModel.phase.allowsMeasurement)
            }
        }
    }

    // MARK: - Private Methods

    private func refresh() {
        Task {
            await viewModel.refresh()
            await simulators.reloadIfOpened()
        }
    }

}
