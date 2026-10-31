//
//  AnalyticsStub.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 04/04/25.
//

@testable import CleanerXcode

final class AnalyticsStub: Analytics {

    // MARK: - Public Properties

    private(set) var events: [AnalyticsEvent] = []

    var event: AnalyticsEvent? {
        events.last
    }

    // MARK: - Public Methods

    func log(_ event: AnalyticsEvent) {
        events.append(event)
    }

}
