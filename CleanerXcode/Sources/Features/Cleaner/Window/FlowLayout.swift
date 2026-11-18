//
//  FlowLayout.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import SwiftUI

/// Places its subviews in rows at their ideal size, wrapping to a new row instead of truncating
/// (review V4). The breaks come from `FlowRows`; no `GeometryReader`.
struct FlowLayout: Layout {

    // MARK: - Public Properties

    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    // MARK: - Public Methods

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = FlowRows.rows(
            itemWidths: sizes.map(\.width),
            spacing: horizontalSpacing,
            maxWidth: proposal.width ?? .infinity
        )
        let widest = rows.map { width(of: $0, sizes: sizes) }.max() ?? 0
        let height = rows.map { height(of: $0, sizes: sizes) }.reduce(0, +)
            + verticalSpacing * CGFloat(max(rows.count - 1, 0))

        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = FlowRows.rows(itemWidths: sizes.map(\.width), spacing: horizontalSpacing, maxWidth: bounds.width)

        var originY = bounds.minY

        for row in rows {
            let rowHeight = height(of: row, sizes: sizes)

            var originX = bounds.minX

            for index in row {
                subviews[index].place(
                    at: CGPoint(x: originX, y: originY + rowHeight / 2),
                    anchor: .leading,
                    proposal: ProposedViewSize(sizes[index])
                )
                originX += sizes[index].width + horizontalSpacing
            }

            originY += rowHeight + verticalSpacing
        }
    }

    // MARK: - Private Methods

    private func width(of row: [Int], sizes: [CGSize]) -> CGFloat {
        row.map { sizes[$0].width }.reduce(0, +) + horizontalSpacing * CGFloat(max(row.count - 1, 0))
    }

    private func height(of row: [Int], sizes: [CGSize]) -> CGFloat {
        row.map { sizes[$0].height }.max() ?? 0
    }

}
