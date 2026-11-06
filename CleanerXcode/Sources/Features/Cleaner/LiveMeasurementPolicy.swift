//
//  LiveMeasurementPolicy.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// When a category is measured again after its folders change (C40 · tempo real, R2–R4): about
/// 5 s after the changes stop, at most once a minute per category while they go on, and never
/// sooner than a minute after the measurement behind the row's current value started.
nonisolated struct LiveMeasurementPolicy: Equatable, Sendable {

    // MARK: - Public Properties

    /// Every category measured from folders under `~/Library` alone (R2). Left to the complete
    /// measurement: the temporary files (the noisiest folders of the system, and only items older
    /// than the minimum age count), the orphan simulator folders (`/private/var/tmp` and the
    /// `simctl` UDIDs), the old simulators (sized by `simctl`) and the preferences reset (no size).
    static let observedCategoryIDs: Set<CleanupCategoryID> = [
        .removeDerivedData,
        .removeCaches,
        .removeArchives,
        .clearDeviceSupport,
        .clearSimulatorData,
        .clearAuxiliaryDeviceSets,
        .clearSimulatorCaches,
        .removeSwiftPMCache,
        .removeXcodeProducts,
        .removeXcodeUserData,
        .removeProvisioningProfiles,
    ]

    var quietPeriod: Duration = .seconds(5)
    var minimumInterval: Duration = .seconds(60)
    /// How long the system groups the events of a batch.
    var eventLatency: Duration = .seconds(1)
    /// While another measurement or a confirmation runs.
    var busyRetryDelay: Duration = .seconds(5)

    // MARK: - Public Methods

    /// `max(min(last + quiet, first + interval), measurementStart + interval)`.
    func dueDate(firstChangeAt: Date, lastChangeAt: Date, measurementStart: Date?) -> Date {
        let settled = min(
            lastChangeAt.addingTimeInterval(quietPeriod.timeInterval),
            firstChangeAt.addingTimeInterval(minimumInterval.timeInterval)
        )

        guard let measurementStart else { return settled }

        return max(settled, measurementStart.addingTimeInterval(minimumInterval.timeInterval))
    }

    /// A measurement that started at or after the last change already saw it.
    func isCovered(lastChangeAt: Date, measurementStart: Date?) -> Bool {
        measurementStart.map { $0 >= lastChangeAt } ?? false
    }

}
