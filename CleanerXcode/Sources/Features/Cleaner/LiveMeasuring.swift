//
//  LiveMeasuring.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// Whether a category measurement can run now (C40 · tempo real, R4).
enum CategoryMeasurementAvailability: Equatable {
    case available
    /// Another measurement or a confirmation: try again soon.
    case busy
    /// No complete measurement yet, or a cleanup: the next complete measurement covers everything.
    case notReady
}

/// What the live measurement needs from the window's state (C40 · tempo real).
protocol LiveMeasuring: AnyObject {

    var categories: [CleanupCategory] { get }

    /// Cleaning or cancelling: the app itself is changing the folders.
    var isModifyingFiles: Bool { get }

    var categoryMeasurementAvailability: CategoryMeasurementAvailability { get }

    /// When the measurement behind each row's current size started, from any origin.
    var measurementStarts: [CleanupCategoryID: Date] { get }

    /// Measures again only `ids`, keeping the other values.
    func measureCategories(_ ids: Set<CleanupCategoryID>) async

}

extension CleanerViewModel: LiveMeasuring {

    // MARK: - Public Properties

    var isModifyingFiles: Bool {
        switch phase {
        case .cleaning, .cancelling: true
        default: false
        }
    }

    var categoryMeasurementAvailability: CategoryMeasurementAvailability {
        if lastSnapshot == nil || isModifyingFiles {
            return .notReady
        }

        return isMeasuring || !phase.allowsMeasurement ? .busy : .available
    }

}
