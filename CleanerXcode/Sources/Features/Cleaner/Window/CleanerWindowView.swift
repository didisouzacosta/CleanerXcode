//
//  CleanerWindowView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The single window (R14, Figma page 03): the hero with the total and the main action, the fixed
/// notices, and the grouped list. Glass stays on the controls layer only (the toolbar and the
/// hero); the list content has none.
struct CleanerWindowView: View {

    // MARK: - States

    @State private var isShowingFailures = false

    // MARK: - Environments

    @Environment(\.appearsActive) private var appearsActive

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel
    let updates: UpdateStore
    let versionText: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CleanerHeroView(isShowingFailures: $isShowingFailures, viewModel: viewModel)
                    // A cleanup never starts while simulators or a runtime are being deleted.
                    .disabled(simulators.phase.isDeleting)

                CleanerNoticesView(viewModel: viewModel, isDeletingSimulators: simulators.phase.isDeleting)

                if isShowingFailures, let failures = viewModel.phase.report?.failedResults, !failures.isEmpty {
                    FailedItemsCard(results: failures)
                }

                ForEach(sections) { group in
                    CategorySectionView(group: group, viewModel: viewModel)
                }

                SimulatorsSectionView(viewModel: simulators, isLocked: !viewModel.phase.allowsMeasurement)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WindowFooterView(updates: updates, versionText: versionText)
        }
        .toolbar {
            CleanerToolbar(viewModel: viewModel, simulators: simulators)
        }
        .sheet(isPresented: isConfirming) {
            CleanupConfirmationSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.phase.report) {
            isShowingFailures = false
        }
        .onChange(of: appearsActive, initial: true) {
            guard appearsActive else { return }

            Task { await viewModel.windowDidActivate() }
        }
    }

    // MARK: - Private Properties

    private var sections: [CleanerSection.Group] {
        CleanerSection.grouping(viewModel.categories)
    }

    /// Closing the sheet only cancels while it is still a confirmation, never a running cleanup.
    private var isConfirming: Binding<Bool> {
        Binding {
            if case .confirming = viewModel.phase {
                true
            } else {
                false
            }
        } set: { isPresented in
            guard !isPresented, case .confirming = viewModel.phase else { return }

            viewModel.cancel()
        }
    }

}

/// Refresh and Settings, icons with labels for VoiceOver; the system draws them in glass.
private struct CleanerToolbar: ToolbarContent {

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    await viewModel.refresh()
                    await simulators.reloadIfOpened()
                }
            }
            .help("Measure every category again")
            .disabled(!viewModel.phase.allowsMeasurement)

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Settings")
        }
    }

}

#if DEBUG
    #Preview("Ready") {
        CleanerWindowPreview(.ready)
    }

    #Preview("Measuring") {
        CleanerWindowPreview(.measuring)
    }

    #Preview("Nothing selected") {
        CleanerWindowPreview(.nothingSelected)
    }

    #Preview("Nothing to clean") {
        CleanerWindowPreview(.nothingToClean)
    }

    #Preview("Danger confirmation") {
        CleanerWindowPreview(.confirming)
    }

    #Preview("Confirmation with Xcode open") {
        CleanerWindowPreview(.confirmingWhileXcodeIsOpen)
    }

    #Preview("Cleaning") {
        CleanerWindowPreview(.cleaning)
    }

    #Preview("Cancelling") {
        CleanerWindowPreview(.cancelling)
    }

    #Preview("Success") {
        CleanerWindowPreview(.finished(.success))
    }

    #Preview("Partial failure") {
        CleanerWindowPreview(.finished(.partialFailure))
    }

    #Preview("Failure") {
        CleanerWindowPreview(.finished(.failure))
    }

    #Preview("Cancelled") {
        CleanerWindowPreview(.finished(.cancelled))
    }

    #Preview("Permission denied") {
        CleanerWindowPreview(.permissionDenied)
    }

    #Preview("Xcode open") {
        CleanerWindowPreview(.xcodeOpen)
    }

    #Preview("Simulator open") {
        CleanerWindowPreview(.simulatorOpen)
    }

    #Preview("Xcode tools unavailable") {
        CleanerWindowPreview(.toolsUnavailable)
    }

    #Preview("Large text") {
        CleanerWindowPreview(.ready)
            .dynamicTypeSize(.xxxLarge)
    }

    #Preview("Reduce transparency") {
        CleanerWindowPreview(.ready, reducesTransparency: true)
    }

    #Preview("Dark") {
        CleanerWindowPreview(.ready)
            .preferredColorScheme(.dark)
    }
#endif
