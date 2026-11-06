//
//  SectionGridLayout.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import SwiftUI

/// The overview's section grid (C40): the first card takes the whole width, and the others share
/// rows of 1, 2 or 4 equal columns (`OverviewPresentation.sectionColumnCount`), never 3, without a
/// `GeometryReader`. Each row is as tall as its tallest card.
struct SectionGridLayout: Layout {

    // MARK: - Public Properties

    var spacing: CGFloat = OverviewPresentation.sectionGridSpacing

    // MARK: - Public Methods

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        // Without a width (the ideal size) everything stacks in one column.
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let rows = rows(of: subviews, width: width)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(rows.count - 1)

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var originY = bounds.minY

        for row in rows(of: subviews, width: bounds.width) {
            var originX = bounds.minX

            for index in row.indices {
                subviews[index].place(
                    at: CGPoint(x: originX, y: originY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: row.columnWidth, height: row.height)
                )
                originX += row.columnWidth + spacing
            }

            originY += row.height + spacing
        }
    }

    // MARK: - Private Methods

    /// The full-width first row, then rows of equal columns.
    private func rows(of subviews: Subviews, width: CGFloat) -> [Row] {
        guard !subviews.isEmpty else { return [] }

        let columns = OverviewPresentation.sectionColumnCount(availableWidth: width, spacing: spacing)
        let columnWidth = max((width - spacing * CGFloat(columns - 1)) / CGFloat(columns), 0)

        var rows = [row(subviews, indices: 0..<1, columnWidth: width)]
        var start = 1

        while start < subviews.count {
            let end = min(start + columns, subviews.count)

            rows.append(row(subviews, indices: start..<end, columnWidth: columnWidth))
            start = end
        }

        return rows
    }

    private func row(_ subviews: Subviews, indices: Range<Int>, columnWidth: CGFloat) -> Row {
        let height = indices.map { index in
            subviews[index].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
        }
        .max() ?? 0

        return Row(indices: indices, columnWidth: columnWidth, height: height)
    }

}
