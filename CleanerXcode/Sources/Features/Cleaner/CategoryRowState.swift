//
//  CategoryRowState.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// The state of one category row.
enum CategoryRowState: Equatable {

    // MARK: - Cases

    case measuring
    case measured(Int64)
    /// 0 bytes or a missing folder.
    case empty
    case unavailable(UnavailableReason)
    case failed(CleanupError)

    // MARK: - Initializers

    /// A failure only shows when nothing could be measured.
    init(size: CategorySize) {
        if let failure = size.failure, size.bytes == 0 {
            self = .failed(failure)
        } else {
            self = size.bytes == 0 ? .empty : .measured(size.bytes)
        }
    }

    // MARK: - Public Properties

    var isUnavailable: Bool {
        if case .unavailable = self {
            true
        } else {
            false
        }
    }

    // MARK: - Public Methods

    /// The rows known before reading the disk, and the categories left to measure.
    /// - Xcode blocks its own settings (R5).
    /// - Without the tools, everything that runs `simctl` or shuts the simulators down is
    ///   unavailable (R12, R10), and so are the orphan folders without the full simulator list.
    /// - The unavailable simulators take their size from the listing; the reset has no size.
    static func plan(
        for categories: [CleanupCategory],
        restrictions: CleanupRestrictions,
        snapshot: SimulatorSnapshot
    ) -> (rows: [CleanupCategoryID: CategoryRowState], toMeasure: [CleanupCategory]) {
        var rows: [CleanupCategoryID: CategoryRowState] = [:]
        var toMeasure: [CleanupCategory] = []

        for category in categories {
            let needsTools = category.operation.needsSimulatorTools || category.shutsDownSimulators

            if restrictions.isBlocked(category.id) {
                rows[category.id] = .unavailable(.xcodeIsRunning)
            } else if !snapshot.areToolsAvailable, needsTools {
                rows[category.id] = .unavailable(.toolsUnavailable)
            } else if category.operation == .removeOrphanSimulatorTemp, snapshot.knownUDIDs == nil {
                rows[category.id] = .unavailable(.simulatorListUnavailable)
            } else if category.operation == .deleteUnavailableSimulators {
                rows[category.id] = snapshot.listingFailure.map(CategoryRowState.failed)
                    ?? (snapshot.unavailableBytes > 0 ? .measured(snapshot.unavailableBytes) : .empty)
            } else if category.targets.isEmpty {
                rows[category.id] = .empty
            } else {
                rows[category.id] = .measuring
                toMeasure.append(category)
            }
        }

        return (rows, toMeasure)
    }

    /// The row while a new measurement starts. A background measurement (C40) keeps the last
    /// value until the new one arrives; what is known before reading the disk applies at once.
    static func refreshed(
        current: CategoryRowState?,
        planned: CategoryRowState,
        keepingValues: Bool
    ) -> CategoryRowState {
        guard keepingValues, planned == .measuring, let current else { return planned }

        switch current {
        case .measured, .empty, .failed:
            return current

        case .measuring, .unavailable:
            return planned
        }
    }

    // MARK: - Nested Types

    enum UnavailableReason: Equatable {
        /// `xcrun` or `simctl` are missing (R12).
        case toolsUnavailable
        /// Blocked while Xcode runs (R5).
        case xcodeIsRunning
        /// The simulators could not be listed, so no folder can be called an orphan.
        case simulatorListUnavailable
    }

}
