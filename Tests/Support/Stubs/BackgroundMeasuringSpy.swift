//
//  BackgroundMeasuringSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
@testable import CleanerXcode

/// Counts the background measurements; each one ends at once and, when given, sets the time of
/// the last measurement. For the live measurement (C40 · tempo real) it records each category
/// measurement, signals it and, when asked, holds it until `releaseCategoryMeasurement()`.
final class BackgroundMeasuringSpy: BackgroundMeasuring, LiveMeasuring {

    // MARK: - Public Properties

    let categoryMeasurements = AsyncStream.makeStream(of: Set<CleanupCategoryID>.self)

    var lastMeasuredAt: Date?
    var measuredAt: Date?
    var categories: [CleanupCategory]
    var isModifyingFiles = false
    var categoryMeasurementAvailability = CategoryMeasurementAvailability.available
    var measurementStarts: [CleanupCategoryID: Date] = [:]
    var holdsCategoryMeasurements = false

    private(set) var measureCount = 0
    private(set) var measuredCategories: [Set<CleanupCategoryID>] = []
    /// Category measurements whose task was cancelled while they ran.
    private(set) var cancelledCategoryMeasurements = 0

    // MARK: - Private Properties

    private var heldMeasurement: CheckedContinuation<Void, Never>?

    // MARK: - Initializers

    init(lastMeasuredAt: Date? = nil, measuredAt: Date? = nil, categories: [CleanupCategory] = []) {
        self.lastMeasuredAt = lastMeasuredAt
        self.measuredAt = measuredAt
        self.categories = categories
    }

    // MARK: - Public Methods

    func measureInBackground() {
        measureCount += 1

        if let measuredAt {
            lastMeasuredAt = measuredAt
        }
    }

    func measureCategories(_ ids: Set<CleanupCategoryID>) async {
        measuredCategories.append(ids)
        categoryMeasurements.continuation.yield(ids)

        if holdsCategoryMeasurements {
            await withCheckedContinuation { heldMeasurement = $0 }
        }

        if Task.isCancelled {
            cancelledCategoryMeasurements += 1
        }
    }

    func releaseCategoryMeasurement() {
        let held = heldMeasurement

        heldMeasurement = nil
        held?.resume()
    }

}
