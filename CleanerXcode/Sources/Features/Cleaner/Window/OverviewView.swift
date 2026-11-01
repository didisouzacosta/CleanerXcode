//
//  OverviewView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The overview page (Figma page 08): the summary card, the failed items when their details are
/// open, and a card per section that opens its page.
struct OverviewView: View {

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel
    let isShowingFailures: Bool
    let onSelect: (SidebarDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OverviewSummaryCard(hero: HeroContent(viewModel: viewModel), breakdown: breakdown)

            if isShowingFailures, let report = viewModel.phase.report, !report.failedResults.isEmpty {
                FailedItemsCard(
                    results: report.failedResults,
                    title: report.outcome == .failure ? "No item was removed" : "Items that failed"
                )
                .subtleTransition()
            }

            SectionHeaderView(title: "Sections", caption: caption)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                ForEach(groups) { group in
                    SectionCardView(
                        title: group.section.title,
                        subtitle: summary(of: group),
                        systemImage: group.section.systemImage,
                        tint: group.section.tint
                    ) {
                        onSelect(SidebarDestination(section: group.section))
                    }
                }
            }

            SectionCardView(
                title: SidebarDestination.simulatorsAndRuntimes.title,
                subtitle: simulatorsSummary,
                systemImage: SidebarDestination.simulatorsAndRuntimes.systemImage,
                tint: .gray
            ) {
                onSelect(.simulatorsAndRuntimes)
            }
        }
    }

    // MARK: - Private Properties

    private var groups: [CleanerSection.Group] {
        CleanerSection.grouping(viewModel.categories)
    }

    private var breakdown: SpaceBreakdown {
        SpaceBreakdown(groups: groups, selectedIDs: viewModel.selectedIDs, rows: viewModel.rows)
    }

    private var caption: String? {
        let selectedCount = viewModel.categories.count { viewModel.selectedIDs.contains($0.id) }

        return OverviewPresentation.sectionsCaption(phase: viewModel.phase, selectedCount: selectedCount)
            .map { String(localized: $0) }
    }

    private var simulatorsSummary: String {
        SimulatorPresentation.statusDetail(
            phase: simulators.phase,
            devices: simulators.devices,
            duplicateUDIDs: simulators.duplicateUDIDs,
            runtimes: simulators.runtimes
        )
    }

    // MARK: - Private Methods

    private func summary(of group: CleanerSection.Group) -> String {
        SectionSummary(
            categories: group.categories,
            selectedIDs: viewModel.selectedIDs,
            selectedBytes: viewModel.selectedBytes(of: group.categories),
            rows: viewModel.rows,
            phase: viewModel.phase,
            style: OverviewPresentation.cardStyle(phase: viewModel.phase)
        )
        .text
    }

}

#if DEBUG
    #Preview("Ready") {
        CleanerWindowPreview(.ready)
    }

    #Preview("Partial failure · details open") {
        CleanerWindowPreview(.finished(.partialFailure), isShowingFailures: true)
    }
#endif
