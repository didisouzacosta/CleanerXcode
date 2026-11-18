//
//  CleanerPhaseTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

/// The layout animates when the kind of phase changes, never on each cleaned item.
struct CleanerPhaseTests {

    // MARK: - Public Methods

    @Test
    func theProgressOfACleanupKeepsTheSameKind() {
        let first = CleanerPhase.cleaning(CleanupProgress(totalCategories: 5, startedCategories: 1, finishedItems: 1))
        let later = CleanerPhase.cleaning(CleanupProgress(totalCategories: 5, startedCategories: 3, finishedItems: 40))

        #expect(first.kind == later.kind)
        #expect(CleanerPhase.cancelling(freedBytes: 1).kind == CleanerPhase.cancelling(freedBytes: 900).kind)
    }

    @Test
    func differentPhasesHaveDifferentKinds() {
        let report = CleanupReport(results: [])

        #expect(CleanerPhase.ready.kind != CleanerPhase.nothingSelected.kind)
        #expect(CleanerPhase.measuring(first: true).kind != CleanerPhase.measuring(first: false).kind)
        #expect(CleanerPhase.finished(report).kind != CleanerPhase.permissionDenied(report).kind)
    }

}
