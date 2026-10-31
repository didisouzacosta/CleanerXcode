//
//  HimetricaAnalytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Himetrica

/// Sends product events to Himetrica. The SDK is only configured on the first event the user
/// allows, so nothing is initialised while "Send usage statistics" is off.
final class HimetricaAnalytics: Analytics {

    // MARK: - Private Properties

    private let isEnabled: () -> Bool
    private let track: (_ name: String, _ properties: [String: Any]) -> Void

    // MARK: - Initializers

    init(isEnabled: @escaping () -> Bool, track: @escaping (_ name: String, _ properties: [String: Any]) -> Void) {
        self.isEnabled = isEnabled
        self.track = track
    }

    // MARK: - Public Methods

    static func live(apiKey: String, isEnabled: @escaping () -> Bool) -> any Analytics {
        let client = LiveClient(apiKey: apiKey)

        return HimetricaAnalytics(isEnabled: isEnabled, track: client.track)
    }

    func log(_ event: AnalyticsEvent) {
        guard isEnabled() else { return }

        track(event.name, event.properties)
    }

    // MARK: - Nested Types

    private final class LiveClient {

        // MARK: - Private Properties

        private let apiKey: String

        private var isConfigured = false

        // MARK: - Initializers

        init(apiKey: String) {
            self.apiKey = apiKey
        }

        // MARK: - Public Methods

        func track(_ name: String, _ properties: [String: Any]) {
            if !isConfigured {
                Himetrica.configure(
                    with: HimetricaConfig(
                        apiKey: apiKey,
                        autoTrackScreenViews: false,
                        respectAdTracking: false,
                        enableLogging: false
                    )
                )
                isConfigured = true
            }

            Himetrica.shared.track(name, properties: properties)
        }

    }

}
