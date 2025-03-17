//
//  Analytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 16/03/25.
//

import SwiftUI
import FirebaseAnalytics

enum AnalyticsEvent {
    
    enum Social: String {
        case x, github, linkedin
    }
    
    case clear([Shell.Command])
    case social(Social)
    case donate
    
    var name: String {
        switch self {
        case .clear: "clear"
        case .social: "social"
        case .donate: "donate"
        }
    }
    
    var paramaters: [String: Any]? {
        switch self {
        case .clear(let commands):
            ["commands": commands.map { $0.rawValue }.joined(separator: ", ")]
        case .social(let social):
            ["platform": social.rawValue]
        case .donate:
            nil
        }
    }
    
}

protocol AnalyticsRepresentable {
    
    func log(_ event: AnalyticsEvent)
    
}

struct Analytics: AnalyticsRepresentable {
    
    func log(_ event: AnalyticsEvent) {
        FirebaseAnalytics.Analytics.logEvent(
            event.name,
            parameters: event.paramaters
        )
    }
    
}

extension EnvironmentValues {
    
    @Entry var analytics = Analytics()
    
}
