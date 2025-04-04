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
    
    private let commandExecutor = CommandExecutorStub()
    private let analytics = AnalyticsStub()
    private let preferences = Preferences(.test)
    
    // MARK: - Public Methods

    @Test
    mutating func calculateFreeUpSpaceWithSuccess() async throws {
        commandExecutor.result = "{\"derived_data\": 4510292,\"archives\": 0,\"simulator_data\": 17564480,\"xcode_cache\": 1116,\"carthage_cache\": 0,\"device_support_ios\": 4595184,\"device_support_watchos\": 0,\"device_support_tvos\": 0}"
        
        let cleanerStore = CleanerStore(
            commandExecutor: commandExecutor,
            preferences: preferences,
            analytics: analytics
        )
        
        try waitUntil {
            cleanerStore.freeUpSpace != 0
        }

        #expect(cleanerStore.freeUpSpace == 4511408.0)
    }

}
