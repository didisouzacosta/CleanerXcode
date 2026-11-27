//
//  HimetricaAnalyticsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct HimetricaAnalyticsTests {

    // MARK: - Public Methods

    @Test
    func sendsEventNameAndPropertiesThroughTheTracker() {
        let spy = TrackerSpy()
        let analytics = HimetricaAnalytics(isEnabled: { true }, track: spy.track)

        analytics.log(.social(.github))

        #expect(spy.events.count == 1)
        #expect(spy.events.first?.name == "social")
        #expect(spy.events.first?.properties["platform"] as? String == "github")
    }

    @Test
    func doesNotSendWhenTheUserOptedOut() {
        let spy = TrackerSpy()
        let analytics = HimetricaAnalytics(isEnabled: { false }, track: spy.track)

        analytics.log(.donate)

        #expect(spy.events.isEmpty)
    }

    @Test
    func followsOptOutChangesAtRuntime() {
        let spy = TrackerSpy()

        var isEnabled = true

        let analytics = HimetricaAnalytics(isEnabled: { isEnabled }, track: spy.track)

        analytics.log(.donate)
        isEnabled = false
        analytics.log(.updateOpened)

        #expect(spy.events.map(\.name) == ["donate"])
    }

}

private final class TrackerSpy {

    // MARK: - Public Properties

    private(set) var events: [(name: String, properties: [String: Any])] = []

    // MARK: - Public Methods

    func track(_ name: String, _ properties: [String: Any]) {
        events.append((name, properties))
    }

}
