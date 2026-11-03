//
//  CleanerDetailViewTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import SwiftUI
import Testing
@testable import CleanerXcode

/// The detail column's top edge turns hard only while the page's content is under the toolbar, so
/// the title and the subtitle never show it through them and the page at rest has no edge line.
struct CleanerDetailViewTests {

    // MARK: - Public Methods

    @Test
    func keepsTheTopEdgeSoftAtRest() {
        #expect(!CleanerDetailView.isContentUnderToolbar(geometry(offset: -52, topInset: 52)))
    }

    @Test
    func turnsTheTopEdgeHardOnceTheContentReachesTheToolbar() {
        #expect(CleanerDetailView.isContentUnderToolbar(geometry(offset: -51, topInset: 52)))
        #expect(CleanerDetailView.isContentUnderToolbar(geometry(offset: 60, topInset: 52)))
        #expect(CleanerDetailView.isContentUnderToolbar(geometry(offset: 400, topInset: 52)))
    }

    /// Pulling the page down past its top (rubber band) leaves nothing under the toolbar.
    @Test
    func keepsTheTopEdgeSoftWhilePulledPastTheTop() {
        #expect(!CleanerDetailView.isContentUnderToolbar(geometry(offset: -90, topInset: 52)))
    }

    /// Without a toolbar inset (the toolbar hidden in full screen), any offset is under the top.
    @Test
    func followsTheTopInset() {
        #expect(!CleanerDetailView.isContentUnderToolbar(geometry(offset: 0, topInset: 0)))
        #expect(CleanerDetailView.isContentUnderToolbar(geometry(offset: 8, topInset: 0)))
    }

    // MARK: - Private Methods

    private func geometry(offset: CGFloat, topInset: CGFloat) -> ScrollGeometry {
        ScrollGeometry(
            contentOffset: CGPoint(x: 0, y: offset),
            contentSize: CGSize(width: 656, height: 640),
            contentInsets: EdgeInsets(top: topInset, leading: 0, bottom: 82, trailing: 0),
            containerSize: CGSize(width: 676, height: 620)
        )
    }

}
