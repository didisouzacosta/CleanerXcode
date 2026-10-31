//
//  CleanerStoreTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 23/03/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CleanerStoreTests {

    // MARK: - Private Variables

    private let analytics = AnalyticsStub()
    private let errorReporter = ErrorReporterStub()
    private let preferences = Preferences(.test)

    // MARK: - Public Methods

    @Test
    func calculateFreeUpSpaceWithSuccess() async throws {
        let commandExecutor = CommandExecutorStub()
        commandExecutor.result = """
        {"derived_data": 4510292, "archives": 0, "simulator_data": 17564480, "xcode_cache": 1116, \
        "carthage_cache": 0, "device_support_ios": 4595184, "device_support_watchos": 0, "device_support_tvos": 0}
        """

        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics,
            errorReporter: errorReporter
        )

        try await waitUntil {
            cleanerStore.freeUpSpace != 0
        } whileWaiting: {
            #expect(cleanerStore.usedSpace.isLoading == true)
        }

        #expect(cleanerStore.freeUpSpace == 4511408.0)
        #expect(cleanerStore.usedSpace.isLoading == false)
    }

    @Test
    func cleanerDataWithSuccess() async throws {
        let commandExecutor = CommandExecutorStub()
        commandExecutor.result = "done"

        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics,
            errorReporter: errorReporter
        )

        #expect(cleanerStore.status == .idle)

        cleanerStore.clear()

        var total: Double = 0
        var progress: Double = 0

        try await waitUntil {
            cleanerStore.status == .isCompleted
        } whileWaiting: {
            total = cleanerStore.total
            progress = cleanerStore.progress
        }

        #expect(total == 3)
        #expect(progress == 3)
    }

    @Test
    func successfulCleanupLogsASingleCleanerEvent() async throws {
        let analytics = AnalyticsStub()
        let commandExecutor = makeCommandExecutor()
        let cleanerStore = try await makeMeasuredStore(commandExecutor: commandExecutor, analytics: analytics)

        cleanerStore.clear()
        try await waitUntil { cleanerStore.status == .isCompleted }

        let cleanerEvents = analytics.events.filter { $0.name.hasPrefix("cleaner") }
        #expect(cleanerEvents.map(\.name) == ["cleaner"])
        #expect(cleanerEvents.first?
            .properties["categories"] as? String == "remove-archives, remove-caches, remove-derived-data")
        #expect(cleanerEvents.first?.properties["result"] as? String == "success")
        #expect(cleanerEvents.first?.properties["freed_bucket"] as? String == "10-50GB")
    }

    @Test
    func partialFailureLogsTheFailedCategories() async throws {
        let analytics = AnalyticsStub()
        let commandExecutor = makeCommandExecutor()
        commandExecutor.failingScripts = ["remove-caches"]
        let cleanerStore = try await makeMeasuredStore(commandExecutor: commandExecutor, analytics: analytics)

        cleanerStore.clear()
        try await waitUntil { cleanerStore.status == .isCompleted }

        let cleanerEvents = analytics.events.filter { $0.name.hasPrefix("cleaner") }
        #expect(cleanerEvents.map(\.name) == ["cleaner", "cleaner_partial_failure"])
        #expect(cleanerEvents.first?.properties["result"] as? String == "partial_failure")
        #expect(cleanerEvents.last?.properties["failed_categories"] as? String == "remove-caches")
        #expect(cleanerEvents.last?.properties["error_kinds"] as? String == "other")
    }

    @Test
    func totalFailureLogsAFailureResult() async throws {
        let analytics = AnalyticsStub()
        let commandExecutor = makeCommandExecutor()
        commandExecutor.failingScripts = ["remove-archives", "remove-caches", "remove-derived-data"]
        let cleanerStore = try await makeMeasuredStore(commandExecutor: commandExecutor, analytics: analytics)

        cleanerStore.clear()
        try await waitUntil { cleanerStore.status == .isCompleted }

        let cleanerEvents = analytics.events.filter { $0.name.hasPrefix("cleaner") }
        #expect(cleanerEvents.first?.properties["result"] as? String == "failure")
        #expect(cleanerEvents.last?
            .properties["failed_categories"] as? String == "remove-archives, remove-caches, remove-derived-data")
    }

    @Test
    func successfulCleanupLeavesBreadcrumbsWithoutReportingAFailure() async throws {
        let commandExecutor = makeCommandExecutor()
        let cleanerStore = try await makeMeasuredStore(commandExecutor: commandExecutor, analytics: AnalyticsStub())

        cleanerStore.clear()
        try await waitUntil { cleanerStore.status == .isCompleted }

        #expect(errorReporter.stages == [.cleanupStarted, .cleanupFinished])
        #expect(errorReporter.failures.isEmpty)
    }

    @Test
    func partialFailureReportsASingleAggregatedFailure() async throws {
        let commandExecutor = makeCommandExecutor()
        commandExecutor.failingScripts = ["remove-caches"]
        let cleanerStore = try await makeMeasuredStore(commandExecutor: commandExecutor, analytics: AnalyticsStub())

        cleanerStore.clear()
        try await waitUntil { cleanerStore.status == .isCompleted }

        #expect(errorReporter.failures == [
            .cleanupFailed(failedCategories: ["remove-caches"], errorKinds: [.other], totalCategories: 3),
        ])
    }

    // MARK: - Private Methods

    /// 20_000_000 KB of DerivedData: 20.48 GB, inside the "10-50GB" bucket.
    private func makeCommandExecutor() -> CommandExecutorStub {
        let commandExecutor = CommandExecutorStub()
        commandExecutor.result = "done"
        commandExecutor.responses["calculate-free-up-space"] = """
        {"derived_data": 20000000, "archives": 0, "simulator_data": 0, "xcode_cache": 0, \
        "carthage_cache": 0, "device_support_ios": 0, "device_support_watchos": 0, "device_support_tvos": 0}
        """
        return commandExecutor
    }

    private func makeMeasuredStore(
        commandExecutor: CommandExecutorStub,
        analytics: AnalyticsStub
    ) async throws -> CleanerStore {
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics,
            errorReporter: errorReporter
        )

        try await waitUntil { cleanerStore.freeUpSpace != 0 }

        return cleanerStore
    }

}
