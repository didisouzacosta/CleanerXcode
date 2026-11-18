//
//  DemoScript.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    /// One step of the demo's tour of the window (C36).
    enum DemoStep: Equatable, Sendable {
        case wait(Duration)
        case refresh
        case show(SidebarDestination)
        case toggle(CleanupCategoryID)
        case requestClean
        case confirm
        case dismissReport
    }

    /// The tour recorded for the README: measure, look around and pick Archives on its page, clean,
    /// see the report, the simulators page, and back to the overview. Cleaning waits inside
    /// `confirm`, so it adds its own time.
    enum DemoScript {

        // MARK: - Public Properties

        static let tour: [DemoStep] = [
            .show(.overview),
            .refresh,
            .wait(.seconds(5)),
            .show(.xcode),
            .wait(.seconds(3)),
            .show(.userData),
            .wait(.milliseconds(1_500)),
            .toggle(.removeArchives),
            .wait(.milliseconds(2_500)),
            .show(.simulators),
            .wait(.seconds(3)),
            .show(.overview),
            .wait(.milliseconds(1_500)),
            .requestClean,
            .wait(.seconds(3)),
            .confirm,
            .wait(.seconds(4)),
            .show(.simulatorsAndRuntimes),
            .wait(.seconds(4)),
            .dismissReport,
            .show(.overview),
            .wait(.seconds(3)),
        ]

    }
#endif
