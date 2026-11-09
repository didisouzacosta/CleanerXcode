//
//  CleanerToolbar.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// Refresh (⌘R), an icon with a label for VoiceOver that the system draws in glass, only on the
/// cleanup pages (C40). Settings lives in the sidebar, so the toolbar has no gear.
///
/// On the Settings pages the item is hidden, not removed: a window toolbar with no item at all
/// collapses into the compact title bar, with a smaller title and the content higher than on the
/// other pages. A hidden item keeps the toolbar, and its height, with nothing drawn in it.
struct CleanerToolbar: ToolbarContent {

    // MARK: - Public Properties

    let destination: SidebarDestination
    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                .help("Measure every category again")
                .keyboardShortcut("r")
                .disabled(!Self.isRefreshEnabled(destination: destination, phase: viewModel.phase))
        }
        .hidden(!destination.showsCleanupControls)
    }

    // MARK: - Public Methods

    /// Only on the cleanup pages, and never while a cleanup is confirmed, running or cancelling.
    /// The item is hidden on the Settings pages; disabled there too, ⌘R does nothing.
    static func isRefreshEnabled(destination: SidebarDestination, phase: CleanerPhase) -> Bool {
        destination.showsCleanupControls && phase.allowsMeasurement
    }

    // MARK: - Private Methods

    private func refresh() {
        Task {
            await viewModel.refresh()
            await simulators.reloadIfOpened()
        }
    }

}
