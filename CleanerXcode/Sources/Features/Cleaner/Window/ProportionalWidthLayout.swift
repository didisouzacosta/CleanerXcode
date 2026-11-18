//
//  ProportionalWidthLayout.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// Places its subviews side by side, each as wide as its `proportionalWidth` share of the space
/// left after the gaps, without a `GeometryReader`.
struct ProportionalWidthLayout: Layout {

    // MARK: - Public Properties

    let spacing: CGFloat

    // MARK: - Public Methods

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let gaps = spacing * CGFloat(max(subviews.count - 1, 0))
        let available = max(bounds.width - gaps, 0)

        var originX = bounds.minX

        for subview in subviews {
            let width = available * subview[ProportionalWidthKey.self]

            subview.place(
                at: CGPoint(x: originX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            originX += width + spacing
        }
    }

}

nonisolated private struct ProportionalWidthKey: LayoutValueKey {

    // MARK: - Public Properties

    static let defaultValue: CGFloat = 0

}

extension View {

    // MARK: - Public Methods

    /// The share of a `ProportionalWidthLayout`'s width, from 0 to 1.
    func proportionalWidth(_ fraction: Double) -> some View {
        layoutValue(key: ProportionalWidthKey.self, value: CGFloat(fraction))
    }

}
