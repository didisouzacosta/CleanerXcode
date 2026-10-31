//
//  TemporaryFilters.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The filters the remover and the measurement use for the two temporary categories, so what is
/// shown as freeable is exactly what would be removed.
nonisolated enum TemporaryFilters {

    // MARK: - Public Methods

    static func temporaryFiles(
        policy: TemporaryItemsPolicy,
        inspector: TemporaryItemInspector = TemporaryItemInspector(),
        now: Date
    ) -> @Sendable (URL) -> Bool {
        { url in
            // Exclusions, owner, type and the folder's own date rule most items out without a walk.
            guard
                let shallow = inspector.inspect(url, includingContents: false),
                policy.decision(for: shallow, now: now) == .remove,
                let item = inspector.inspect(url)
            else { return false }

            return policy.decision(for: item, now: now) == .remove
        }
    }

    static func orphanSimulatorTemp(
        finder: OrphanSimulatorTempFinder,
        policy: TemporaryItemsPolicy,
        inspector: TemporaryItemInspector = TemporaryItemInspector(),
        now: Date
    ) -> @Sendable (URL) -> Bool {
        { url in
            guard
                finder.isOrphan(url),
                let shallow = inspector.inspect(url, includingContents: false),
                policy.simulatorTempDecision(for: shallow, now: now) == .remove,
                let item = inspector.inspect(url)
            else { return false }

            return policy.simulatorTempDecision(for: item, now: now) == .remove
        }
    }

}
