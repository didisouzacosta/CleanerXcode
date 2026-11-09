//
//  DemoSession.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    import AppKit

    /// Runs the demo in the real window (C36): light appearance, the default window size centered on
    /// the screen, a pause for the screen recording to start, then the tour.
    enum DemoSession {

        // MARK: - Public Properties

        static let windowContentSize = NSSize(width: 920, height: 620)

        // MARK: - Private Properties

        /// The window's task starts again when it is closed and reopened; the tour plays once.
        private static var runClaim = RunClaim()

        // MARK: - Public Methods

        /// Before the window appears, so it never draws in dark first.
        static func applyAppearance() {
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        }

        /// The simulators load first, so the overview's card shows them from the start.
        static func run(
            viewModel: CleanerViewModel,
            simulators: SimulatorsViewModel,
            router: AppRouter,
            startDelay: Duration
        ) async {
            guard runClaim.claim() else { return }

            arrangeMainWindow()

            await simulators.load()

            do {
                try await Task.sleep(for: startDelay)
            } catch {
                return
            }

            let driver = DemoTourDriver(viewModel: viewModel, router: router)

            await DemoDirector(steps: DemoScript.tour).run(on: driver)
        }

        // MARK: - Private Methods

        /// macOS restores the last frame; the recording always uses the default size, in an active
        /// window, so the toolbar and the prominent button draw as the user sees them.
        private static func arrangeMainWindow() {
            guard let window = NSApplication.shared.windows.first(where: \.canBecomeMain) else { return }

            window.setContentSize(windowContentSize)
            window.center()
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
        }

        // MARK: - Nested Types

        /// `true` only the first time.
        struct RunClaim {

            // MARK: - Private Properties

            private var isClaimed = false

            // MARK: - Public Methods

            mutating func claim() -> Bool {
                guard !isClaimed else { return false }

                isClaimed = true

                return true
            }

        }

    }
#endif
