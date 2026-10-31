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
        VStack(alignment: .leading, spacing: 8) {
            CollapsibleSectionHeader(isCollapsed: $isCollapsed, title: group.section.title, summary: summary)

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(group.categories) { category in
                        CategoryRowView(category: category, viewModel: viewModel)
                    }
                }
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
            }
        }
    }

    // MARK: - Private Properties

    private var summary: LocalizedStringResource {
        let isSelected = group.categories.contains { viewModel.selectedIDs.contains($0.id) }

        guard isSelected else { return "nothing selected" }

        let bytes = viewModel.selectedBytes(of: group.categories)
        return "\(bytes.formatted(.byteCount(style: .file))) selected"
    }

    // MARK: - Initializers

    init(group: CleanerSection.Group, viewModel: CleanerViewModel) {
        self.group = group
        self.viewModel = viewModel
        _isCollapsed = AppStorage(wrappedValue: false, group.section.collapsedStorageKey)
    }

}
