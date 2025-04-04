//
//  CleanerStoreTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 23/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct CleanerStoreTests {
    
    // MARK: - Private Variables
    
    private let analytics = AnalyticsStub()
    private let preferences = Preferences(.test)
    
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
        
        try waitUntil {
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
            analytics: analytics
        )
        
        #expect(cleanerStore.status == .idle)
        
        cleanerStore.clear()
        
        var stepsTotal: Double = 0
        
        try waitUntil {
            cleanerStore.status == .isCompleted
        } whileWaiting: {
            stepsTotal = cleanerStore.total
        }
        
        #expect(stepsTotal == 3)
        #expect(cleanerStore.status == .isCompleted)
    }

}
