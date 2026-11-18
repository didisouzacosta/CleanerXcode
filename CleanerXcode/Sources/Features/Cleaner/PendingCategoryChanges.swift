//
//  PendingCategoryChanges.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// The categories whose folders changed and that wait to be measured again (C40 · tempo real).
nonisolated struct PendingCategoryChanges: Equatable, Sendable {

    // MARK: - Public Properties

    var ids: Set<CleanupCategoryID> {
        Set(entries.keys)
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    // MARK: - Private Properties

    private var entries: [CleanupCategoryID: Entry] = [:]

    // MARK: - Public Methods

    /// Keeps the first change of each category and moves its last one.
    mutating func record(_ ids: Set<CleanupCategoryID>, at date: Date) {
        for id in ids {
            entries[id] = Entry(firstChangeAt: entries[id]?.firstChangeAt ?? date, lastChangeAt: date)
        }
    }

    func nextDueDate(policy: LiveMeasurementPolicy, measurementStarts: [CleanupCategoryID: Date]) -> Date? {
        entries.map { id, entry in
            policy.dueDate(
                firstChangeAt: entry.firstChangeAt,
                lastChangeAt: entry.lastChangeAt,
                measurementStart: measurementStarts[id]
            )
        }.min()
    }

    /// Removes and returns the categories due at `date`, all together; the ones a measurement
    /// already covered are removed without being returned, and the rest keep waiting.
    mutating func takeDue(
        at date: Date,
        policy: LiveMeasurementPolicy,
        measurementStarts: [CleanupCategoryID: Date]
    ) -> Set<CleanupCategoryID> {
        var due: Set<CleanupCategoryID> = []

        for (id, entry) in entries {
            let start = measurementStarts[id]

            if policy.isCovered(lastChangeAt: entry.lastChangeAt, measurementStart: start) {
                entries[id] = nil
            } else if
                policy.dueDate(
                    firstChangeAt: entry.firstChangeAt,
                    lastChangeAt: entry.lastChangeAt,
                    measurementStart: start
                ) <= date
            {
                entries[id] = nil
                due.insert(id)
            }
        }

        return due
    }

    mutating func removeAll() {
        entries = [:]
    }

    // MARK: - Nested Types

    private struct Entry: Equatable {
        let firstChangeAt: Date
        let lastChangeAt: Date
    }

}
