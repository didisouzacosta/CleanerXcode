//
//  CategorySectionView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// A collapsible group of the list. Whether it is collapsed is kept per section.
struct CategorySectionView: View {

    // MARK: - States

    @AppStorage private var isCollapsed: Bool

    // MARK: - Public Properties

    let group: CleanerSection.Group
    let viewModel: CleanerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CollapsibleSectionHeader(isCollapsed: $isCollapsed, title: group.section.title, summary: summary)

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(group.categories) { category in
                        CategoryRowView(category: category, viewModel: viewModel)
                    }
                }
                .background(Palette.card, in: .rect(cornerRadius: 12))
                .subtleTransition()
            }
        }
    }

    // MARK: - Private Properties

    private var summary: String {
        SectionSummary(
            categories: group.categories,
            selectedIDs: viewModel.selectedIDs,
            selectedBytes: viewModel.selectedBytes(of: group.categories),
            rows: viewModel.rows,
            report: viewModel.phase.report,
            isCollapsed: isCollapsed
        )
        .text
    }

    // MARK: - Initializers

    init(group: CleanerSection.Group, viewModel: CleanerViewModel) {
        self.group = group
        self.viewModel = viewModel
        _isCollapsed = AppStorage(wrappedValue: false, group.section.collapsedStorageKey)
    }

}
