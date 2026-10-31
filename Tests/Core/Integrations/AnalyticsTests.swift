//
//  AnalyticsTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct AnalyticsTests {

    // MARK: - Private Properties

    private let analytics = AnalyticsStub()

    @Test
    func ensureDonateEventConsistency() throws {
        analytics.log(.donate)

        #expect(analytics.event?.name == "donate")
        #expect(analytics.event?.properties.values.first == nil)
    }

    @Test
    func ensureSocialEventConsistency() throws {
        analytics.log(.social(.github))

        #expect(analytics.event?.name == "social")
        #expect(analytics.event?.properties["platform"] as? String == "github")

        analytics.log(.social(.linkedin))

        #expect(analytics.event?.name == "social")
        #expect(analytics.event?.properties["platform"] as? String == "linkedin")

        analytics.log(.social(.xPlatform))

        #expect(analytics.event?.name == "social")
        #expect(analytics.event?.properties["platform"] as? String == "x")
    }

    @Test
    func ensureCleanerEventConsistency() throws {
        analytics.log(
            .cleaner(
                categories: ["remove-derived-data", "remove-caches"],
                result: .partialFailure,
                freedBytes: 12_400_000_000
            )
        )

        #expect(analytics.event?.name == "cleaner")
        #expect(analytics.event?.properties["categories"] as? String == "remove-derived-data, remove-caches")
        #expect(analytics.event?.properties["result"] as? String == "partial_failure")
        #expect(analytics.event?.properties["freed_bucket"] as? String == "10-50GB")
    }

    @Test(arguments: [
        (Int64(0), "<1GB"),
        (Int64(999_999_999), "<1GB"),
        (Int64(1_000_000_000), "1-10GB"),
        (Int64(9_999_999_999), "1-10GB"),
        (Int64(10_000_000_000), "10-50GB"),
        (Int64(50_000_000_000), ">50GB"),
    ])
    func ensureFreedBuckets(bytes: Int64, bucket: String) {
        let event = AnalyticsEvent.cleaner(categories: [], result: .success, freedBytes: bytes)

        #expect(event.properties["freed_bucket"] as? String == bucket)
    }

    @Test
    func ensurePartialFailureEventConsistency() {
        let event = AnalyticsEvent.cleanerPartialFailure(
            failedCategories: ["remove-derived-data"],
            errorKinds: [.inUse, .permission, .inUse]
        )

        #expect(event.name == "cleaner_partial_failure")
        #expect(event.properties["failed_categories"] as? String == "remove-derived-data")
        #expect(event.properties["error_kinds"] as? String == "in_use, permission")
    }

    @Test
    func ensureSimulatorAndRuntimeEventsConsistency() {
        let deleted = AnalyticsEvent.simulatorDeleted(count: 3, reason: .duplicate)
        let unavailable = AnalyticsEvent.simulatorUnavailableDeleted(count: 2)
        let runtime = AnalyticsEvent.runtimeDeleted(count: 1)

        #expect(deleted.name == "simulator_deleted")
        #expect(deleted.properties["count"] as? Int == 3)
        #expect(deleted.properties["reason"] as? String == "duplicate")
        #expect(unavailable.name == "simulator_unavailable_deleted")
        #expect(unavailable.properties["count"] as? Int == 2)
        #expect(runtime.name == "runtime_deleted")
        #expect(runtime.properties["count"] as? Int == 1)
    }

    @Test
    func ensureUpdateOpenedEventConsistency() {
        #expect(AnalyticsEvent.updateOpened.name == "update_opened")
        #expect(AnalyticsEvent.updateOpened.properties.isEmpty)
    }

    @Test
    func eventNamesAndPropertiesFollowTheStableContract() {
        let events: [AnalyticsEvent] = [
            .cleaner(categories: ["remove-caches"], result: .success, freedBytes: 1),
            .cleanerPartialFailure(failedCategories: ["remove-caches"], errorKinds: [.timeout]),
            .simulatorDeleted(count: 1, reason: .manual),
            .simulatorUnavailableDeleted(count: 1),
            .runtimeDeleted(count: 1),
            .social(.github),
            .donate,
            .updateOpened,
        ]

        for event in events {
            #expect(event.name.range(of: "^[a-z][a-z0-9_]*$", options: .regularExpression) != nil)

            for value in event.properties.values {
                #expect(value is String || value is Int)
            }
        }
    }

}
