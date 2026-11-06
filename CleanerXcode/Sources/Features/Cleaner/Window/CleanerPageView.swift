//
//  CleanerPageView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// The notices of the page, then its content: a cleanup page, the overview or a Settings page.
/// It has no preview of its own: the window's previews show every page through it.
struct CleanerPageView: View {

    // MARK: - Public Properties

    let destination: SidebarDestination
    let isShowingFailures: Bool
    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel
    let settings: SettingsViewModel
    let updates: UpdateViewModel
    let versionText: String
    let onSelect: (SidebarDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !notices.isEmpty {
                CleanerNoticesView(
                    notices: notices,
                    viewModel: viewModel,
                    isDeletingSimulators: simulators.phase.isDeleting
                )
                .subtleTransition()
            }

            switch destination {
            case .overview:
                OverviewView(
                    viewModel: viewModel,
                    simulators: simulators,
                    isShowingFailures: isShowingFailures,
                    onSelect: onSelect
                )

            case .simulatorsAndRuntimes:
                SimulatorsPageView(viewModel: simulators, isLocked: !viewModel.phase.allowsMeasurement)

            case .xcode, .simulators, .temporary, .userData:
                if let group {
                    CategoryPageView(group: group, viewModel: viewModel)
                }

            case .general:
                GeneralSettingsView(viewModel: settings)

            case .about:
                AboutSettingsView(viewModel: settings, updates: updates, versionText: versionText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .subtleAnimation(value: viewModel.phase.kind)
        .subtleAnimation(value: viewModel.rows)
        .subtleAnimation(value: viewModel.selectedIDs)
        .subtleAnimation(value: viewModel.restrictions)
        .subtleAnimation(value: isShowingFailures)
    }

    // MARK: - Private Properties

    private var notices: [CleanerNotice] {
        CleanerNotice.notices(
            for: destination,
            phase: viewModel.phase,
            restrictions: viewModel.restrictions,
            areSimulatorToolsUnavailable: viewModel.areSimulatorToolsUnavailable,
            trashBound: viewModel.trashBoundCategoryIDs
        )
    }

    private var group: CleanerSection.Group? {
        CleanerSection.grouping(viewModel.categories).first { $0.section == destination.section }
    }

}
