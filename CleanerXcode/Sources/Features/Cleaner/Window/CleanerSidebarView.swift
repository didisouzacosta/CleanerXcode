//
//  CleanerSidebarView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The native sidebar (Figma page 08): "Overview", the four cleanup sections with what each would
/// free, and "Simulators and runtimes" with the duplicates as a badge. The footer stays pinned in
/// the bottom safe area, with the list scrolling under it.
/// The sidebar has no background of its own: macOS draws it in glass.
struct CleanerSidebarView: View {

    // MARK: - Bindings

    @Binding var selection: SidebarDestination

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel
    let updates: UpdateViewModel
    let versionText: String
    let onSupport: () -> Void

    var body: some View {
        List(selection: optionalSelection) {
            SidebarRow(destination: .overview)

            Section("Cleanup") {
                ForEach(SidebarDestination.destinations(in: .cleanup)) { destination in
                    SidebarRow(destination: destination, trailing: trailingText(for: destination))
                }
            }

            Section("Manage") {
                SidebarRow(destination: .simulatorsAndRuntimes, badge: badgeCount)
            }
        }
        .listStyle(.sidebar)
        // No toggle in the toolbar, as in the layout; ⌃⌘S and the View menu still show or hide
        // the sidebar. It must come before the column width: applied after it, the width is
        // dropped and the sidebar opens at about 144 pt (review V2).
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewColumnWidth(min: 220, ideal: 244, max: 320)
        // R42: the list scrolls under the pinned footer with the soft edge at the top and the
        // bottom; `safeAreaBar` (unlike `safeAreaInset`) drives the bottom edge effect.
        .scrollEdgeEffectStyle(.soft, for: .all)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            SidebarFooterView(updates: updates, versionText: versionText, onSupport: onSupport)
        }
    }

    // MARK: - Private Properties

    /// The list deselects on an empty click; the page never goes blank, so `nil` is ignored.
    private var optionalSelection: Binding<SidebarDestination?> {
        Binding {
            selection
        } set: { destination in
            if let destination {
                selection = destination
            }
        }
    }

    private var badgeCount: Int {
        SimulatorPresentation.duplicateBadgeCount(
            phase: simulators.phase,
            duplicateCount: simulators.duplicateUDIDs.count
        ) ?? 0
    }

    // MARK: - Private Methods

    private func trailingText(for destination: SidebarDestination) -> String? {
        guard
            let section = destination.section,
            let group = CleanerSection.grouping(viewModel.categories).first(where: { $0.section == section })
        else {
            return nil
        }

        return SectionSummary(
            categories: group.categories,
            selectedIDs: viewModel.selectedIDs,
            selectedBytes: viewModel.selectedBytes(of: group.categories),
            rows: viewModel.rows,
            phase: viewModel.phase,
            style: .bytes
        )
        .sidebarText
    }

}

/// One symbol and one line, with a short status on the right, like a native source list.
private struct SidebarRow: View {

    // MARK: - Public Properties

    let destination: SidebarDestination

    /// Already localized.
    var trailing: String?

    /// Hidden at zero.
    var badge = 0

    var body: some View {
        HStack(spacing: 6) {
            Label {
                Text(destination.sidebarTitle)
                    .lineLimit(1)
            } icon: {
                Image(systemName: destination.systemImage)
            }

            Spacer(minLength: 4)

            Text(verbatim: trailing ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.opacity)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: trailing ?? ""))
        // The tag must be the outermost modifier the list sees: a badge applied around the row
        // hides it and the list ignores the selection.
        .badge(badge)
        .tag(destination)
    }

}

#if DEBUG
    #Preview("Sidebar") {
        CleanerWindowPreview(.ready)
    }
#endif
