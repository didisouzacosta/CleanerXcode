//
//  MixpanelAnalytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import SwiftUI
import Mixpanel

@Observable
final class MixpanelAnalytics: Analytics {
    
    static let shared = MixpanelAnalytics()
    
    func log(_ event: AnalyticsEvent) {
        Mixpanel.safeMainInstance()?.track(
            event: event.name,
            properties: event.properties.toMixpanelProperties()
        )
    }
    
}

extension [String: Any] {
    
    func toMixpanelProperties() -> Properties {
        keys.reduce(into: [:]) { partial, key in
            if let value = partial[key] {
                partial[key] = value
            }
        }
    }
    
}
