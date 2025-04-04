//
//  AnalyticsStub.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 04/04/25.
//

@testable import CleanerXcode

final class AnalyticsStub: Analytics {
    
    var event: AnalyticsEvent?
    
    func log(_ event: AnalyticsEvent) {
        self.event = event
    }
    
}
