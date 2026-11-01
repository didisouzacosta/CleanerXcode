//
//  SimulatorsSectionView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// "Manage simulators" at the end of the list (R8, R9, flow 2.3): expanding it loads the
/// simulators and the runtimes, summed up in the "Simulators and runtimes" row that opens the
/// lists (Figma page 03). Collapsed by default, and both choices are kept.
struct SimulatorsSectionView: View {

    // MARK: - States

    @AppStorage private var isCollapsed: Bool
    @AppStorage private var isListExpanded: Bool

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    /// While a cleanup runs, nothing here can be deleted.
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CollapsibleSectionHeader(isCollapsed: $isCollapsed, title: "Manage simulators", summary: summary)

            if !isCollapsed {
                SimulatorsSummaryRow(isListExpanded: $isListExpanded, viewModel: viewModel, onRetry: retry)
                    .subtleTransition()

                if isListExpanded, viewModel.phase.showsLists {
                    SimulatorsListView(viewModel: viewModel, isLocked: isLocked)
                        .subtleTransition()
                }
            }
        }
        .subtleAnimation(value: viewModel.phase)
        .subtleAnimation(value: viewModel.selectedUDIDs)
        .sheet(item: confirmation) { confirmation in
            SimulatorsConfirmationSheet(confirmation: confirmation, viewModel: viewModel)
        }
        .onChange(of: isCollapsed, initial: true) {
            guard !isCollapsed, needsLoading else { return }

            Task { await viewModel.load() }
        }
    }

    // MARK: - Private Properties

    private var summary: String {
        SimulatorPresentation.sectionSummary(
            deviceCount: viewModel.devices.count,
            duplicateCount: viewModel.duplicateUDIDs.count,
            isLoaded: viewModel.phase.showsLists,
            isCollapsed: isCollapsed
        )?
            .text ?? ""
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

    /// The section starts collapsed, so `simctl` only runs once the owner opens it (C21; the
    /// layout's open section is pending the owner's decision). Previews start open.
    init(
        viewModel: SimulatorsViewModel,
        isLocked: Bool,
        isInitiallyCollapsed: Bool = true,
        isListInitiallyExpanded: Bool = false
    ) {
        self.viewModel = viewModel
        self.isLocked = isLocked
        _isCollapsed = AppStorage(wrappedValue: isInitiallyCollapsed, "section-collapsed-manage-simulators")
        _isListExpanded = AppStorage(wrappedValue: isListInitiallyExpanded, "simulators-list-expanded")
    }

    // MARK: - Private Methods

    private func retry() {
        Task { await viewModel.load() }
    }

}

/// The two lists with their actions, each collapsible like in the approved layout (Figma 9:1366).
private struct SimulatorsListView: View {

    // MARK: - States

    @AppStorage("section-collapsed-simulator-devices") private var areDevicesCollapsed = false
    @AppStorage("section-collapsed-simulator-runtimes") private var areRuntimesCollapsed = false

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

            CollapsibleSectionHeader(
                isCollapsed: $areDevicesCollapsed,
                title: "Simulators",
                summary: String(localized: simulatorsDetail)
            )

            if !areDevicesCollapsed {
                actions
                    .subtleTransition()

                if !viewModel.devices.isEmpty {
                    card {
                        ForEach(viewModel.devices) { device in
                            SimulatorRowView(device: device, viewModel: viewModel, isLocked: isLocked)
                        }
                    }
                    .subtleTransition()
                }
            }

            CollapsibleSectionHeader(
                isCollapsed: $areRuntimesCollapsed,
                title: "Runtimes",
                summary: String(localized: runtimesDetail)
            )

            if !areRuntimesCollapsed, !viewModel.runtimes.isEmpty {
                card {
                    ForEach(viewModel.runtimes) { runtime in
                        RuntimeRowView(runtime: runtime, viewModel: viewModel, isLocked: isLocked)
                    }
                }
                .subtleTransition()
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
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .disabled(isBusy || viewModel.duplicateUDIDs.isEmpty)

                Button {
                    viewModel.requestDeleteSelected()
                } label: {
                    let count = viewModel.selectedUDIDs.count

                    Text(count > 0 ? "Remove \(count) simulators" : "Remove simulators")
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.red)
                .disabled(isBusy || viewModel.selectedUDIDs.isEmpty)
            }
        }
    }

    // MARK: - Private Methods

    private func card(@ViewBuilder _ rows: () -> some View) -> some View {
        VStack(spacing: 0) {
            rows()
        }
        .padding(.vertical, 4)
        .background(Palette.card, in: .rect(cornerRadius: 12))
    }

}

/// "Simulators and runtimes": what the lists hold, or why there are none. Once loaded, it opens
/// and closes the lists.
private struct SimulatorsSummaryRow: View {

    // MARK: - Bindings

    @Binding var isListExpanded: Bool

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    let onRetry: () -> Void

    var body: some View {
        Group {
            // Only the loaded lists open; a "Try again" never sits inside another button.
            if viewModel.phase.showsLists {
                Button {
                    withAnimation(.snappy) {
                        isListExpanded.toggle()
                    }
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityValue(isListExpanded ? Text("Expanded") : Text("Collapsed"))
                .accessibilityHint("Shows or hides the items of this section")
            } else {
                content
                    .accessibilityElement(children: .contain)
            }
        }
        .background(Palette.card, in: .rect(cornerRadius: 12))
    }

    // MARK: - Private Properties

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: "macbook.and.iphone")
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Simulators and runtimes")

                Text(verbatim: detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            accessory
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 14)
        .contentShape(.rect)
        // The line truncates; the whole reason stays reachable.
        .help(detail)
    }

    @ViewBuilder
    private var accessory: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView()
                .controlSize(.small)

        case .empty:
            EmptyView()

        case .toolsUnavailable, .failed:
            Button("Try again", action: onRetry)
                .controlSize(.small)

        case .loaded, .deleting:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isListExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
    }

    /// Already localized: the loaded summary joins several plurals.
    private var detail: String {
        switch viewModel.phase {
        case .idle, .loading:
            return String(localized: "Loading the simulators…")

        case .empty:
            return String(localized: "No simulators or runtimes")

        case .toolsUnavailable:
            return String(localized: "Unavailable without Xcode")

        case let .failed(error):
            return String(localized: "Could not list the simulators: \(String(localized: error.summary))")

        case .loaded, .deleting:
            return loadedDetail
        }
    }

    /// "14 simulators · 3 duplicates (7.2 GB) · 2 runtimes (15.1 GB)".
    private var loadedDetail: String {
        let duplicates = viewModel.devices.filter { viewModel.duplicateUDIDs.contains($0.udid) }
        let duplicateBytes = duplicates.reduce(0) { $0 + $1.sizeBytes }
        let runtimeBytes = viewModel.runtimes.reduce(0) { $0 + $1.sizeBytes }

        var parts = [String(localized: "\(viewModel.devices.count) simulators")]

        if !duplicates.isEmpty {
            parts.append("\(String(localized: "\(duplicates.count) duplicates")) (\(Self.format(duplicateBytes)))")
        }

        parts.append("\(String(localized: "\(viewModel.runtimes.count) runtimes")) (\(Self.format(runtimeBytes)))")

        return parts.joined(separator: " · ")
    }

    // MARK: - Private Methods

    private static func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

}

private extension SimulatorsPhase {

    var showsLists: Bool {
        switch self {
        case .loaded, .deleting: true
        default: false
        }
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
