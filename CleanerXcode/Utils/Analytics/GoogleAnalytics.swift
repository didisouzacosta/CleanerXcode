//
//  GoogleAnalytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import SwiftUI
import FirebaseAnalytics

@Observable
final class GoogleAnalytics: Analytics {
    
    static let shared = GoogleAnalytics()
    
    func log(_ event: AnalyticsEvent) {
        #if !DEBUG
        FirebaseAnalytics.Analytics.logEvent(
            event.name,
            parameters: event.properties
        )
        #endif
    }
    
}
