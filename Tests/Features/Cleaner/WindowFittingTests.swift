//
//  WindowFittingTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import CleanerXcode

/// The window follows the height of its content up to what the screen can show; past that, the
/// list scrolls (owner request, 2026-10-31).
struct WindowFittingTests {

    // MARK: - Public Methods

    @Test
    func aShortListSizesTheWindowToItsContent() {
        #expect(WindowFitting.frameHeight(content: 600, chrome: 52, screenHeight: 1_000) == 652)
    }

    @Test
    func aLongListStopsAtTheScreenAndScrolls() {
        #expect(WindowFitting.frameHeight(content: 1_600, chrome: 52, screenHeight: 1_000) == 1_000)
    }

    /// Before the first measurement there is nothing to follow yet.
    @Test
    func nothingMeasuredKeepsTheCurrentHeight() {
        #expect(WindowFitting.frameHeight(content: 0, chrome: 52, screenHeight: 1_000) == nil)
    }

    /// The top edge stays where it is; the window only moves up when the bottom would leave the
    /// screen.
    @Test
    func keepsTheTopEdgeInsideTheScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 1_000)
        let frame = CGRect(x: 100, y: 300, width: 560, height: 600)

        #expect(WindowFitting.frame(frame, height: 400, in: screen) == CGRect(x: 100, y: 500, width: 560, height: 400))
        #expect(WindowFitting.frame(frame, height: 1_000, in: screen) == CGRect(
            x: 100,
            y: 0,
            width: 560,
            height: 1_000
        ))
    }

    /// A window restored or dragged above the visible area comes back under the menu bar.
    @Test
    func neverLeavesTheTopEdgeAboveTheScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 1_000)
        let frame = CGRect(x: 100, y: 700, width: 560, height: 600)

        #expect(WindowFitting.frame(frame, height: 500, in: screen) == CGRect(x: 100, y: 500, width: 560, height: 500))
    }

    /// The scene's minimum content height (320 pt) holds even for a tiny list.
    @Test
    func keepsTheMinimumContentHeight() {
        #expect(WindowFitting.frameHeight(content: 100, chrome: 52, screenHeight: 1_000) == CGFloat(320 + 52))
    }

}
