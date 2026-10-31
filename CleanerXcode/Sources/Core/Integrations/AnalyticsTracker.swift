//
//  AnalyticsTracker.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Observation

/// Exposes the chosen `Analytics` implementation through the SwiftUI environment.
@Observable
final class AnalyticsTracker: Analytics {

    // MARK: - Private Properties

    @ObservationIgnored private let backend: any Analytics

    // MARK: - Initializers

    init(_ backend: any Analytics) {
        self.backend = backend
    }

    // MARK: - Public Methods

    func log(_ event: AnalyticsEvent) {
        backend.log(event)
    }

}
