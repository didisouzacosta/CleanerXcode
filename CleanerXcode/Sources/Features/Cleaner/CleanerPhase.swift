//
//  CleanerPhase.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// The window's state (plan section 2.4).
enum CleanerPhase: Equatable {

    // MARK: - Cases

    case measuring(first: Bool)
    case ready
    case nothingSelected
    case nothingToClean
    case confirming(CleanupPlan)
    case cleaning(CleanupProgress)
    case cancelling
    case finished(CleanupReport)
    case permissionDenied(CleanupReport)

    // MARK: - Public Properties

    var report: CleanupReport? {
        switch self {
        case let .finished(report), let .permissionDenied(report): report
        default: nil
        }
    }

    /// Measuring never runs while a plan is being confirmed or cleaned.
    var allowsMeasurement: Bool {
        switch self {
        case .confirming, .cleaning, .cancelling: false
        default: true
        }
    }

}
