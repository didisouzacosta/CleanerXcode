//
//  CleanerStoreTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 23/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

@MainActor
@Suite(.serialized)
struct CleanerStoreTests {
    
    // MARK: - Private Variables
    
    private let analytics = AnalyticsStub()
    private let preferences: Preferences

    // MARK: - Initializer

    init() {
        let userDefaults = UserDefaults(suiteName: "CleanerStoreTests")!
        userDefaults.removePersistentDomain(forName: "CleanerStoreTests")
        preferences = Preferences(userDefaults)
    }
    
    // MARK: - Public Methods

    @Test
    func calculateFreeUpSpaceWithSuccess() async throws {
        let commandExecutor = CommandExecutorStub()
        commandExecutor.result = "{\"derived_data\": 4510292,\"archives\": 0,\"simulator_data\": 17564480,\"xcode_cache\": 1116,\"carthage_cache\": 0,\"device_support_ios\": 4595184,\"device_support_watchos\": 0,\"device_support_tvos\": 0}"
        
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
        )
        
        try await waitUntil {
            cleanerStore.freeUpSpace != 0
        } whileWaiting: {
            #expect(cleanerStore.usedSpace.isLoading == true)
        }

        #expect(cleanerStore.freeUpSpace == 4_619_681_792.0)
        #expect(cleanerStore.usedSpace.isLoading == false)
    }

    @Test
    func cleanerDataWithSuccess() async throws {
        let commandExecutor = CommandExecutorStub()
        commandExecutor.result = "done"
        
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
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
    func cancellationStopsExecutorAndRestoresIdleState() async throws {
        let commandExecutor = BlockingCommandExecutor()
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
        )

        cleanerStore.clear()
        cleanerStore.cancelCleaning()

        #expect(commandExecutor.isCancelled)
        #expect(cleanerStore.status == .idle)
    }

    @Test
    func partialCommandFailureProducesErrorState() async throws {
        let commandExecutor = FailingCommandExecutor()
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
        )

        cleanerStore.clear()

        try await waitUntil {
            cleanerStore.status == .error
        }

        #expect(cleanerStore.status == .error)
    }

    @Test
    func refreshesUsedSpacePeriodically() async throws {
        let commandExecutor = RefreshCountingCommandExecutor()
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics,
            refreshInterval: 0.05
        )

        try await waitUntil {
            commandExecutor.calculationCount >= 2
        }

        #expect(commandExecutor.calculationCount >= 2)
        cleanerStore.cancelCleaning()
    }

}

private final class BlockingCommandExecutor: CommandExecutor, @unchecked Sendable {

    private(set) var isCancelled = false

    func run(_ command: Command) async throws -> String? {
        if command == .calculateFreeUpSpace {
            return "{}"
        }

        try await Task.sleep(for: .seconds(5))

        return nil
    }

    func cancel() {
        isCancelled = true
    }

}

private struct FailingCommandExecutor: CommandExecutor {

    let isCancelled = false

    func run(_ command: Command) async throws -> String? {
        if command == .calculateFreeUpSpace {
            return "{}"
        }

        if command == .removeCaches {
            throw "Expected command failure"
        }

        return "done"
    }

    func cancel() {}

}

private final class RefreshCountingCommandExecutor: CommandExecutor, @unchecked Sendable {

    private(set) var calculationCount = 0
    let isCancelled = false

    func run(_ command: Command) async throws -> String? {
        guard command == .calculateFreeUpSpace else { return "done" }

        calculationCount += 1

        return "{}"
    }

    func cancel() {}

}
