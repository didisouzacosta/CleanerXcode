//
//  AnalyticsTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct AnalyticsTests {

    private let analytics = AnalyticsStub()
    
    @Test
    func ensureDonateEventConsistency() async throws {
        analytics.log(.donate)
        
        #expect(analytics.event?.name == "donate")
        #expect(analytics.event?.properties.values.first == nil)
    }
    
    @Test
    func ensureSocialEventConsistency() async throws {
        analytics.log(.social(.github))
        
        #expect(analytics.event?.name == "social")
        #expect(analytics.event?.properties["platform"] as? String == "github")
        
        analytics.log(.social(.linkedin))
        
        #expect(analytics.event?.name == "social")
        #expect(analytics.event?.properties["platform"] as? String == "linkedin")
        
        analytics.log(.social(.x))
        
        #expect(analytics.event?.name == "social")
        #expect(analytics.event?.properties["platform"] as? String == "x")
    }
    
    @Test func ensureCleanerEventConsistency() async throws {
        analytics.log(.cleaner(Command.commands))
        
        #expect(analytics.event?.name == "cleaner")
        #expect(analytics.event?.properties["commands"] as? String == "remove-archives, remove-caches, remove-derived-data, clear-device-support, clear-simulator-data, remove-old-simulators, reset-xcode-preferences, calculate-free-up-space")
    }

}
