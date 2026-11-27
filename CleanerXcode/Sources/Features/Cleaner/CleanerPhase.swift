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
    /// Keeps what was freed before the cancel, which the hero still shows.
    case cancelling(freedBytes: Int64)
    case finished(CleanupReport)
    case permissionDenied(CleanupReport)

    // MARK: - Public Properties

    var report: CleanupReport? {
        switch self {
        case let .finished(report), let .permissionDenied(report): report
        default: nil
        }
    }

    /// The kind of phase without its progress: the layout animates when it changes, never on each
    /// cleaned item.
    var kind: Kind {
        switch self {
        case let .measuring(first): .measuring(first: first)
        case .ready: .ready
        case .nothingSelected: .nothingSelected
        case .nothingToClean: .nothingToClean
        case .confirming: .confirming
        case .cleaning: .cleaning
        case .cancelling: .cancelling
        case let .finished(report): .finished(report.outcome)
        case .permissionDenied: .permissionDenied
        }
    }

    /// Measuring never runs while a plan is being confirmed or cleaned.
    var allowsMeasurement: Bool {
        switch self {
        case .confirming, .cleaning, .cancelling: false
        default: true
        }
    }

    // MARK: - Nested Types

    enum Kind: Hashable {
        case measuring(first: Bool)
        case ready
        case nothingSelected
        case nothingToClean
        case confirming
        case cleaning
        case cancelling
        case finished(CleanupReport.Outcome)
        case permissionDenied
    }

}
