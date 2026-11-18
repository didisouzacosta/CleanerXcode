//
//  NullAnalytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// Used in tests, previews and debug builds: events are discarded.
final class NullAnalytics: Analytics {

    func log(_ event: AnalyticsEvent) {}

}
