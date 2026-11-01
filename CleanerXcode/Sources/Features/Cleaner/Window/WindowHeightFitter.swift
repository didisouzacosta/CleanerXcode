//
//  WindowHeightFitter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit
import SwiftUI

/// Resizes the window to its content height (`WindowFitting`), animating the frame so the change
/// is smooth (measured: about 20 eased steps both ways); SwiftUI alone resizes the window in one
/// jump. The first fit, before the window shows, is not animated. The window is left alone while
/// the owner resizes it, in full screen and when zoomed.
struct WindowHeightFitter: NSViewRepresentable {

    // MARK: - Public Properties

    /// The scrolling area plus the footer; `0` until measured.
    let contentHeight: CGFloat

    // MARK: - Public Methods

    func makeNSView(context: Context) -> FittingView {
        FittingView()
    }

    func updateNSView(_ nsView: FittingView, context: Context) {
        nsView.contentHeight = contentHeight
    }

    // MARK: - Nested Types

    final class FittingView: NSView {

        // MARK: - Public Properties

        var contentHeight: CGFloat = 0 {
            didSet {
                guard contentHeight != oldValue else { return }

                scheduleFit()
            }
        }

        // MARK: - Private Properties

        private var isFitScheduled = false
        private var isAnimatingFrame = false

        // MARK: - Public Methods

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleFit()
        }

        override func viewDidEndLiveResize() {
            super.viewDidEndLiveResize()
            scheduleFit()
        }

        // MARK: - Private Methods

        /// Fits once per run of changes, outside SwiftUI's update pass.
        private func scheduleFit() {
            guard !isFitScheduled else { return }

            isFitScheduled = true

            Task { [weak self] in
                self?.isFitScheduled = false
                self?.fit()
            }
        }

        private func fit() {
            guard
                let window,
                !isAnimatingFrame,
                !window.inLiveResize,
                !window.styleMask.contains(.fullScreen),
                !window.isZoomed,
                let screen = window.screen ?? NSScreen.main
            else { return }

            let visible = screen.visibleFrame
            let chrome = window.frame.height - window.contentLayoutRect.height

            guard
                let height = WindowFitting.frameHeight(
                    content: contentHeight,
                    chrome: chrome,
                    screenHeight: visible.height
                ),
                abs(height - window.frame.height) > 0.5
            else { return }

            let frame = WindowFitting.frame(window.frame, height: height, in: visible)

            guard window.isVisible else {
                window.setFrame(frame, display: false)
                return
            }

            // The window's own resize animation, smooth both ways (the animator proxy jumps when
            // the window grows); it runs to the end before returning. Reduce Motion resizes at once.
            isAnimatingFrame = true
            window.setFrame(frame, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
            isAnimatingFrame = false

            // The content may have changed during the animation: follow its latest height.
            scheduleFit()
        }

    }

}
