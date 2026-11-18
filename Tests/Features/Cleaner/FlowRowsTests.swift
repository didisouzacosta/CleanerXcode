//
//  FlowRowsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import CoreGraphics
import Testing
@testable import CleanerXcode

/// How the space legend wraps (review V4): items keep their full width and move to a new row
/// instead of truncating.
struct FlowRowsTests {

    // MARK: - Public Methods

    @Test
    func everythingThatFitsStaysOnOneRow() {
        #expect(FlowRows.rows(itemWidths: [100, 120, 90, 110], spacing: 16, maxWidth: 628) == [[0, 1, 2, 3]])
        #expect(FlowRows.rows(itemWidths: [100, 120], spacing: 16, maxWidth: .infinity) == [[0, 1]])
    }

    /// 100 + 16 + 100 = 216 fits exactly; one more point of item does not.
    @Test
    func theSpacingCountsTowardsTheWidth() {
        #expect(FlowRows.rows(itemWidths: [100, 100], spacing: 16, maxWidth: 216) == [[0, 1]])
        #expect(FlowRows.rows(itemWidths: [100, 101], spacing: 16, maxWidth: 216) == [[0], [1]])
    }

    @Test
    func itemsThatDoNotFitMoveToTheNextRow() {
        #expect(FlowRows.rows(itemWidths: [100, 120, 90, 110], spacing: 16, maxWidth: 260) == [[0, 1], [2, 3]])
        #expect(FlowRows.rows(itemWidths: [100, 120, 90, 110], spacing: 16, maxWidth: 230) == [[0], [1, 2], [3]])
    }

    /// An item wider than the row sits alone instead of being cut.
    @Test
    func aWideItemSitsAloneOnItsRow() {
        #expect(FlowRows.rows(itemWidths: [50, 300, 50], spacing: 16, maxWidth: 200) == [[0], [1], [2]])
    }

    @Test
    func nothingToPlaceHasNoRows() {
        #expect(FlowRows.rows(itemWidths: [], spacing: 16, maxWidth: 200).isEmpty)
    }

}
