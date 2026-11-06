//
//  PendingCategoryChangesTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The categories whose folders changed and wait to be measured again (C40 · tempo real, R3–R4).
struct PendingCategoryChangesTests {

    // MARK: - Private Properties

    private let policy = LiveMeasurementPolicy()
    private let start = Date(timeIntervalSince1970: 100_000)

    // MARK: - Public Methods

    @Test
    func recordingAgainKeepsTheFirstChangeAndMovesTheLast() {
        var pending = PendingCategoryChanges()

        pending.record([.removeDerivedData], at: start)
        pending.record([.removeDerivedData], at: start.addingTimeInterval(30))

        #expect(pending.ids == [.removeDerivedData])
        #expect(
            pending.nextDueDate(policy: policy, measurementStarts: [:]) == start.addingTimeInterval(35),
            "min(last + 5, first + 60)"
        )

        pending.record([.removeDerivedData], at: start.addingTimeInterval(58))

        #expect(pending.nextDueDate(policy: policy, measurementStarts: [:]) == start.addingTimeInterval(60))
    }

    @Test
    func theNextDueDateIsTheEarliest() {
        var pending = PendingCategoryChanges()

        pending.record([.removeArchives], at: start.addingTimeInterval(20))
        pending.record([.removeDerivedData], at: start)

        #expect(pending.nextDueDate(policy: policy, measurementStarts: [:]) == start.addingTimeInterval(5))
    }

    @Test
    func nothingPendingHasNoDueDate() {
        #expect(PendingCategoryChanges().nextDueDate(policy: policy, measurementStarts: [:]) == nil)
        #expect(PendingCategoryChanges().isEmpty)
    }

    /// Coalescing: every category due at the same time goes in one measurement.
    @Test
    func takingTheDueOnesReturnsThemTogetherAndKeepsTheFutureOnes() {
        var pending = PendingCategoryChanges()

        pending.record([.removeDerivedData, .removeCaches], at: start)
        pending.record([.removeArchives], at: start.addingTimeInterval(4))

        let due = pending.takeDue(at: start.addingTimeInterval(5), policy: policy, measurementStarts: [:])

        #expect(due == [.removeDerivedData, .removeCaches])
        #expect(pending.ids == [.removeArchives])
    }

    /// A measurement that started after the last change already saw it.
    @Test
    func aCoveredCategoryIsDroppedWithoutBeingReturned() {
        var pending = PendingCategoryChanges()

        pending.record([.removeDerivedData], at: start)

        let due = pending.takeDue(
            at: start.addingTimeInterval(5),
            policy: policy,
            measurementStarts: [.removeDerivedData: start.addingTimeInterval(1)]
        )

        #expect(due.isEmpty)
        #expect(pending.isEmpty)
    }

    @Test
    func aRecentMeasurementKeepsTheCategoryWaiting() {
        var pending = PendingCategoryChanges()

        pending.record([.removeDerivedData], at: start)

        let starts = [CleanupCategoryID.removeDerivedData: start.addingTimeInterval(-10)]
        let due = pending.takeDue(at: start.addingTimeInterval(5), policy: policy, measurementStarts: starts)

        #expect(due.isEmpty)
        #expect(pending.ids == [.removeDerivedData])
        #expect(pending.nextDueDate(policy: policy, measurementStarts: starts) == start.addingTimeInterval(50))
    }

    @Test
    func removingAllClearsEverything() {
        var pending = PendingCategoryChanges()

        pending.record([.removeDerivedData, .removeArchives], at: start)
        pending.removeAll()

        #expect(pending.isEmpty)
        #expect(pending.ids.isEmpty)
    }

}
