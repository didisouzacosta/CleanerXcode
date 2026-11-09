//
//  CleanerDetailView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The detail column (Figma page 08): the page of the selected destination, scrolling under the
/// toolbar and under the fixed action bar (R41, R42). Under the toolbar the edge turns hard while
/// the content is there, so the title and the subtitle stay legible, and stays soft at rest; under
/// the bar it is always soft. The bar sits in the bottom safe area, with no background of its own.
/// The Settings pages (C40) have neither the bar nor Refresh.
struct CleanerDetailView: View {

    // MARK: - States

    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var isContentUnderToolbar = false

    // MARK: - Environments

    @Environment(\.openURL) private var openURL

    // MARK: - Bindings

    @Binding var destination: SidebarDestination
    @Binding var isShowingFailures: Bool

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel
    let settings: SettingsViewModel
    let updates: UpdateViewModel
    let versionText: String

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CleanerPageView(
                    destination: destination,
                    isShowingFailures: isShowingFailures,
                    viewModel: viewModel,
                    simulators: simulators,
                    settings: settings,
                    updates: updates,
                    versionText: versionText,
                    onSelect: select
                )
                .id(destination)
                .subtleTransition()
            }
            .padding(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))
            .subtleAnimation(value: destination)
        }
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: Bool.self, of: Self.isContentUnderToolbar) { _, isUnder in
            isContentUnderToolbar = isUnder
        }
        // The title and the subtitle in the toolbar have no backing of their own: the hard edge
        // keeps the content from showing through them, however the page scrolls. At rest it stays
        // soft, so no edge line shows. The bottom stays soft under the bar (R42).
        .scrollEdgeEffectStyle(isContentUnderToolbar ? .hard : .soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Palette.window)
        .navigationTitle(Text(destination.title))
        .navigationSubtitle(Text(verbatim: subtitle))
        .toolbar {
            CleanerToolbar(destination: destination, viewModel: viewModel, simulators: simulators)
        }
        .safeAreaBar(edge: .bottom) {
            if destination.showsCleanupControls {
                ActionBarView(content: barContent, onAction: perform)
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
                    // A cleanup never starts while simulators or a runtime are being deleted.
                    .disabled(simulators.phase.isDeleting)
                    .subtleAnimation(value: viewModel.phase.kind)
                    .subtleTransition()
            }
        }
        .subtleAnimation(value: destination.showsCleanupControls)
        .onChange(of: destination) {
            scrollToTop()
        }
    }

    // MARK: - Private Properties

    private var barContent: ActionBarContent {
        ActionBarContent(
            hero: HeroContent(viewModel: viewModel),
            phase: viewModel.phase,
            isShowingDetails: isShowingFailures
        )
    }

    /// The section's count, the simulators' status, and nothing on the overview or Settings.
    private var subtitle: String {
        switch destination {
        case .overview, .general, .about:
            return ""

        case .simulatorsAndRuntimes:
            return SimulatorPresentation.statusDetail(
                phase: simulators.phase,
                devices: simulators.devices,
                duplicateUDIDs: simulators.duplicateUDIDs,
                runtimes: simulators.runtimes
            )

        case .xcode, .simulators, .temporary, .userData:
            guard
                let group = CleanerSection.grouping(viewModel.categories)
                    .first(where: { $0.section == destination.section })
            else {
                return ""
            }

            return SectionSummary(
                categories: group.categories,
                selectedIDs: viewModel.selectedIDs,
                selectedBytes: viewModel.selectedBytes(of: group.categories),
                rows: viewModel.rows,
                phase: viewModel.phase,
                style: .count
            )
            .text
        }
    }

    // MARK: - Public Methods

    /// Whether the page's content has reached the area under the toolbar (the top inset).
    nonisolated static func isContentUnderToolbar(_ geometry: ScrollGeometry) -> Bool {
        geometry.contentOffset.y + geometry.contentInsets.top > 0
    }

    // MARK: - Private Methods

    private func select(_ newDestination: SidebarDestination) {
        destination = newDestination
    }

    /// A new page starts at its top; the jump has no animation, so only the page's fade shows.
    private func scrollToTop() {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            scrollPosition.scrollTo(edge: .top)
        }
    }

    private func perform(_ kind: HeroContent.Action.Kind) {
        switch kind {
        case .clean:
            Task { await viewModel.requestClean() }

        case .cancel:
            viewModel.cancel()

        case .dismiss:
            viewModel.dismissReport()

        case .retry:
            Task { await viewModel.retryFailed() }

        case .toggleDetails:
            toggleDetails()

        case .openPrivacySettings:
            openURL(HeroContent.fullDiskAccessURL)

        case .supportProject:
            viewModel.supportProject()
        }
    }

    /// The failed items live on the overview: from another page, the button opens it with them.
    private func toggleDetails() {
        if destination == .overview {
            isShowingFailures.toggle()
        } else {
            destination = .overview
            isShowingFailures = true
        }
    }

}

#if DEBUG
    #Preview("Xcode") {
        CleanerWindowPreview(.ready, destination: .xcode)
    }
#endif
