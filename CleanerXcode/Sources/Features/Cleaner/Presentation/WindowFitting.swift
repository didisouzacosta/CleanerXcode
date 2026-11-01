//
//  WindowFitting.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import CoreGraphics
import Foundation

/// The window follows the height of its content up to what the screen can show; past that, the
/// list scrolls (owner request, 2026-10-31). No empty band ever sits under the content.
enum WindowFitting {

    // MARK: - Public Properties

    /// The scene's minimum content height (`CleanerXcodeApp`).
    static let minimumContentHeight: CGFloat = 320

    // MARK: - Public Methods

    /// The window height for this content (scrolling area and footer) under the title bar and
    /// toolbar (`chrome`); `nil` before the first measurement.
    static func frameHeight(content: CGFloat, chrome: CGFloat, screenHeight: CGFloat) -> CGFloat? {
        guard content > 0 else { return nil }

        return min(max(content, minimumContentHeight) + chrome, screenHeight)
    }

    /// The new frame keeps its top edge inside the screen, and only moves up when its bottom would
    /// leave it.
    static func frame(_ frame: CGRect, height: CGFloat, in screen: CGRect) -> CGRect {
        let top = min(frame.maxY, screen.maxY)
        let originY = max(top - height, screen.minY)

        return CGRect(x: frame.minX, y: originY, width: frame.width, height: height)
    }

}
