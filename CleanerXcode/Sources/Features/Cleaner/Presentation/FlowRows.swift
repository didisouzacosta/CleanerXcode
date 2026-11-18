//
//  FlowRows.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import CoreGraphics

/// The line breaks of a flow of items, such as the space legend (review V4): each item keeps its
/// full width and moves to a new row when it would pass the available width, so nothing is cut.
/// Pure and `nonisolated`: `FlowLayout` calls it from the nonisolated `Layout` methods.
nonisolated enum FlowRows {

    // MARK: - Public Methods

    /// The item indices of each row, in order. An item wider than `maxWidth` sits alone on its row.
    static func rows(itemWidths: [CGFloat], spacing: CGFloat, maxWidth: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0

        for (index, width) in itemWidths.enumerated() {
            let widthWithItem = current.isEmpty ? width : currentWidth + spacing + width

            if !current.isEmpty, widthWithItem > maxWidth {
                rows.append(current)
                current = [index]
                currentWidth = width
            } else {
                current.append(index)
                currentWidth = widthWithItem
            }
        }

        if !current.isEmpty {
            rows.append(current)
        }

        return rows
    }

}
