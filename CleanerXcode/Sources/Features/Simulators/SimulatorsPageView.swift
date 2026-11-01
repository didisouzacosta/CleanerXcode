//
//  SimulatorsPageView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The "Simulators and runtimes" page (R8, R9, Figma page 08): once listed, the simulators with
/// their actions and the runtimes; otherwise a card that tells why there is nothing to show.
/// Every deletion waits for the confirmation sheet.
struct SimulatorsPageView: View {

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    /// While a cleanup runs, nothing here can be deleted.
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let failure = viewModel.lastFailure {
                Label {
                    Text("Could not delete: \(failure.summary)")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.callout)
                .subtleTransition()
            }

            if viewModel.phase.showsLists {
                SimulatorsListsView(viewModel: viewModel, isLocked: isLocked)
                    .subtleTransition()
            } else {
                SimulatorsStatusCard(viewModel: viewModel, onRetry: retry)
                    .subtleTransition()
            }
        }
        .subtleAnimation(value: viewModel.phase)
        .subtleAnimation(value: viewModel.selectedUDIDs)
        .subtleAnimation(value: viewModel.lastFailure)
        .sheet(item: confirmation) { confirmation in
            SimulatorsConfirmationSheet(confirmation: confirmation, viewModel: viewModel)
        }
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - Private Properties

    private var confirmation: Binding<SimulatorsViewModel.Confirmation?> {
        Binding {
            viewModel.confirmation
        } set: { confirmation in
            if confirmation == nil {
                viewModel.cancelConfirmation()
            }
        }
    }

    // MARK: - Private Methods

    /// Unstructured, so leaving the page never cancels the listing into a failure (D9).
    private func loadIfNeeded() {
        Task { await viewModel.loadIfNeeded() }
    }

    private func retry() {
        Task { await viewModel.load() }
    }

}

/// The two lists with their headers and actions (Figma 37:1058).
private struct SimulatorsListsView: View {

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Simulators",
                caption: SimulatorPresentation.devicesCaption(
                    devices: viewModel.devices,
                    duplicateUDIDs: viewModel.duplicateUDIDs
                )
            )

            SimulatorsActions(viewModel: viewModel, isBusy: isBusy)

            if !viewModel.devices.isEmpty {
                ListCard {
                    ForEach(viewModel.devices) { device in
                        SimulatorRowView(device: device, viewModel: viewModel, isLocked: isLocked)
                    }
                }
            }

            SectionHeaderView(
                title: "Runtimes",
                caption: SimulatorPresentation.runtimesCaption(runtimes: viewModel.runtimes)
            )
            .padding(.top, 8)

            if !viewModel.runtimes.isEmpty {
                ListCard {
                    ForEach(viewModel.runtimes) { runtime in
                        RuntimeRowView(runtime: runtime, viewModel: viewModel, isLocked: isLocked)
                    }
                }
            }
        }
    }

    // MARK: - Private Properties

    private var isBusy: Bool {
        isLocked || viewModel.phase.isDeleting
    }

}

/// "Select duplicates" only pre-selects (R8); "Remove n simulators" asks first.
private struct SimulatorsActions: View {

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    let isBusy: Bool

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: viewModel.selectDuplicates) {
                    Text("Select duplicates (\(viewModel.duplicateUDIDs.count))")
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(isBusy || viewModel.duplicateUDIDs.isEmpty)

                Button(action: viewModel.requestDeleteSelected) {
                    Text(removeTitle)
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.red)
                .disabled(isBusy || viewModel.selectedUDIDs.isEmpty)
            }
        }
    }

    // MARK: - Private Properties

    private var removeTitle: LocalizedStringResource {
        let count = viewModel.selectedUDIDs.count

        return count > 0 ? "Remove \(count) simulators" : "Remove simulators"
    }

}

/// Loading, empty, the tools missing or a failure, with "Try again" where it helps.
private struct SimulatorsStatusCard: View {

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: SidebarDestination.simulatorsAndRuntimes.systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Simulators and runtimes")

                Text(verbatim: detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            accessory
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Palette.card, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var accessory: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView()
                .controlSize(.small)

        case .toolsUnavailable, .failed:
            Button("Try again", action: onRetry)
                .controlSize(.small)

        case .empty, .loaded, .deleting:
            EmptyView()
        }
    }

    private var detail: String {
        SimulatorPresentation.statusDetail(
            phase: viewModel.phase,
            devices: viewModel.devices,
            duplicateUDIDs: viewModel.duplicateUDIDs,
            runtimes: viewModel.runtimes
        )
    }

}

private struct ListCard<Rows: View>: View {

    // MARK: - Public Properties

    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(spacing: 0) {
            rows
        }
        .padding(.vertical, 4)
        .background(Palette.card, in: .rect(cornerRadius: 12))
    }

}

#if DEBUG
    #Preview("Loaded with duplicates") {
        SimulatorsSectionPreview(.loaded)
    }

    #Preview("Loading") {
        SimulatorsSectionPreview(.loading)
    }

    #Preview("Empty") {
        SimulatorsSectionPreview(.empty)
    }

    #Preview("Xcode tools unavailable") {
        SimulatorsSectionPreview(.toolsUnavailable)
    }

    #Preview("Failed") {
        SimulatorsSectionPreview(.failed)
    }

    #Preview("Deleting") {
        SimulatorsSectionPreview(.deleting)
    }

    #Preview("Runtime confirmation") {
        SimulatorsSectionPreview(.confirmingRuntime)
    }

    #Preview("Simulators confirmation") {
        SimulatorsSectionPreview(.confirmingDevices)
    }

    #Preview("Could not delete") {
        SimulatorsSectionPreview(.deleteFailed)
    }

    #Preview("Unavailable simulator and runtime states") {
        SimulatorsSectionPreview(.unusualStates)
    }

    #Preview("Locked during a cleanup") {
        SimulatorsSectionPreview(.loaded, isLocked: true)
    }

    #Preview("Dark") {
        SimulatorsSectionPreview(.loaded)
            .preferredColorScheme(.dark)
    }

    #Preview("In the window") {
        CleanerWindowPreview(.ready, destination: .simulatorsAndRuntimes)
    }
#endif
