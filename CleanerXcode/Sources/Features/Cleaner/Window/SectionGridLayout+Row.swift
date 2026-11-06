//
//  SectionGridLayout+Row.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import CoreGraphics

extension SectionGridLayout {

    // MARK: - Row

    /// One row of the grid: which subviews, how wide each one is and how tall the row is.
    struct Row: Equatable {

        // MARK: - Public Properties

        let indices: Range<Int>
        let columnWidth: CGFloat
        let height: CGFloat

    }

}
