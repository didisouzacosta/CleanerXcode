//
//  CleanupExecutorSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
@testable import CleanerXcode

/// Records each plan, replays scripted events and returns scripted reports. Optionally it waits
/// until the caller cancels, like a long cleanup.
final class CleanupExecutorSpy: CleanupExecuting {

    // MARK: - Public Properties

    private(set) var plans: [CleanupPlan] = []

    let started = AsyncStream.makeStream(of: Void.self)

    // MARK: - Private Properties

    private var reports: [CleanupReport]

    private let events: [CleanupEvent]
    private let waitsForCancellation: Bool

    // MARK: - Initializers

    init(reports: [CleanupReport] = [], events: [CleanupEvent] = [], waitsForCancellation: Bool = false) {
        self.reports = reports
        self.events = events
        self.waitsForCancellation = waitsForCancellation
    }

    // MARK: - Public Methods

    func execute(_ plan: CleanupPlan, onEvent: @escaping (CleanupEvent) -> Void) async -> CleanupReport {
        plans.append(plan)
        events.forEach(onEvent)
        started.continuation.yield()

        if waitsForCancellation {
            try? await Task.sleep(for: .seconds(60))

            let done = events.compactMap { event -> CleanupItemResult? in
                guard case let .itemFinished(result) = event else { return nil }

                return result
            }

            return CleanupReport(results: done, wasCancelled: Task.isCancelled)
        }

        return reports.isEmpty ? CleanupReport(results: []) : reports.removeFirst()
    }

}
