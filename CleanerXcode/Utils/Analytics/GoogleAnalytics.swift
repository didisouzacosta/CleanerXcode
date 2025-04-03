//
//  GoogleAnalytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import SwiftUI
import FirebaseAnalytics

struct GoogleAnalytics: Analytics {
    
    static let shared = GoogleAnalytics()
    
    func log(_ event: AnalyticsEvent) {
        FirebaseAnalytics.Analytics.logEvent(
            event.name,
            parameters: event.paramaters
        )
    }
    
}

extension EnvironmentValues {
    
    @Entry var analytics = GoogleAnalytics()
    
}
