//
//  SimulatorsSectionView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// "Manage simulators" at the end of the list (R8, R9, flow 2.3): expanding it loads the
/// simulators and the runtimes. Collapsed by default, and the choice is kept.
struct SimulatorsSectionView: View {

    // MARK: - States

    @AppStorage private var isCollapsed: Bool

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    /// While a cleanup runs, nothing here can be deleted.
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CollapsibleSectionHeader(isCollapsed: $isCollapsed, title: "Manage simulators", summary: summary)

            if !isCollapsed {
                content
            }
        }
        .sheet(item: confirmation) { confirmation in
            SimulatorsConfirmationSheet(confirmation: confirmation, viewModel: viewModel)
        }
        .onChange(of: isCollapsed, initial: true) {
            guard !isCollapsed, needsLoading else { return }

            Task { await viewModel.load() }
        }
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            SimulatorsMessage(systemImage: nil, text: "Loading the simulators…", onRetry: nil)

        case .empty:
            SimulatorsMessage(systemImage: "checkmark.circle", text: "No simulators or runtimes", onRetry: retry)

        case .toolsUnavailable:
            SimulatorsMessage(systemImage: "wrench.and.screwdriver", text: "Needs the Xcode tools", onRetry: retry)

        case let .failed(error):
            SimulatorsMessage(
                systemImage: "exclamationmark.triangle",
                text: "Could not list the simulators: \(error.summary)",
                onRetry: retry
            )

        case .loaded, .deleting:
            SimulatorsListView(viewModel: viewModel, isLocked: isLocked)
        }
    }

    private var summary: LocalizedStringResource {
        let duplicates = viewModel.duplicateUDIDs.count

        switch viewModel.phase {
        case .loaded, .deleting:
            return duplicates > 0 ? "\(duplicates) duplicates" : "\(viewModel.devices.count) simulators"

        default:
            return ""
        }
    }

    /// Lists again on expanding unless the lists are shown or being changed.
    private var needsLoading: Bool {
        switch viewModel.phase {
        case .loaded, .loading, .deleting: false
        default: true
        }
    }

    private var confirmation: Binding<SimulatorsViewModel.Confirmation?> {
        Binding {
            viewModel.confirmation
        } set: { confirmation in
            if confirmation == nil {
                viewModel.cancelConfirmation()
            }
        }
    }

    // MARK: - Initializers

    /// Previews start expanded; the app starts collapsed until the owner opens it.
    init(viewModel: SimulatorsViewModel, isLocked: Bool, isInitiallyCollapsed: Bool = true) {
        self.viewModel = viewModel
        self.isLocked = isLocked
        _isCollapsed = AppStorage(wrappedValue: isInitiallyCollapsed, "section-collapsed-manage-simulators")
    }

    // MARK: - Private Methods

    private func retry() {
        Task { await viewModel.load() }
    }

}

/// The two lists with their actions.
private struct SimulatorsListView: View {

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
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
            }

            subheader("Simulators", detail: simulatorsDetail)

            actions

            if !viewModel.devices.isEmpty {
                card {
                    ForEach(viewModel.devices) { device in
                        SimulatorRowView(device: device, viewModel: viewModel, isLocked: isLocked)
                    }
                }
            }

            subheader("Runtimes", detail: runtimesDetail)

            if !viewModel.runtimes.isEmpty {
                card {
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

    private var simulatorsDetail: LocalizedStringResource {
        let duplicates = viewModel.devices.filter { viewModel.duplicateUDIDs.contains($0.udid) }
        let bytes = duplicates.reduce(0) { $0 + $1.sizeBytes }.formatted(.byteCount(style: .file))

        guard !duplicates.isEmpty else { return "\(viewModel.devices.count)" }

        let duplicateCount = String(localized: "\(duplicates.count) duplicates")

        return "\(viewModel.devices.count) · \(duplicateCount) (\(bytes))"
    }

    private var runtimesDetail: LocalizedStringResource {
        let bytes = viewModel.runtimes.reduce(0) { $0 + $1.sizeBytes }.formatted(.byteCount(style: .file))

        return "\(bytes) in \(String(localized: "\(viewModel.runtimes.count) runtimes"))"
    }

    private var actions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    viewModel.selectDuplicates()
                } label: {
                    Text("Select duplicates (\(viewModel.duplicateUDIDs.count))")
                }
                .buttonStyle(.glass)
                .disabled(isBusy || viewModel.duplicateUDIDs.isEmpty)

                Button {
                    viewModel.requestDeleteSelected()
                } label: {
                    let count = viewModel.selectedUDIDs.count

                    Text(count > 0 ? "Remove \(count) simulators" : "Remove simulators")
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .disabled(isBusy || viewModel.selectedUDIDs.isEmpty)
            }
        }
    }

    // MARK: - Private Methods

    private func subheader(_ title: LocalizedStringResource, detail: LocalizedStringResource) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func card(@ViewBuilder _ rows: () -> some View) -> some View {
        VStack(spacing: 0) {
            rows()
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
    }

}

/// Loading, empty, missing tools and failures.
private struct SimulatorsMessage: View {

    // MARK: - Public Properties

    let systemImage: String?
    let text: LocalizedStringResource
    let onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let onRetry {
                Button("Try again", action: onRetry)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
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

    // macOS ignores `dynamicTypeSize` for these text styles (renders are identical); the real
    // large-text check is in C27.
    #Preview("Large text") {
        SimulatorsSectionPreview(.loaded)
            .dynamicTypeSize(.xxxLarge)
    }

    #Preview("Dark") {
        SimulatorsSectionPreview(.loaded)
            .preferredColorScheme(.dark)
    }
#endif
