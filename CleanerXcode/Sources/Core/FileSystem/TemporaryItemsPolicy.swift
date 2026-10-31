//
//  TemporaryItemsPolicy.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Decides which direct children of the temporary folders can go (R11). AI tools and terminals
/// keep live files there, so only the user's own files, folders and links that nothing touched
/// for `minimumAge` are removed, and a fixed list is never touched.
nonisolated struct TemporaryItemsPolicy: Sendable {

    // MARK: - Type Properties

    /// D7: 3 days, with 1, 3, 7 and 14 offered in Settings (C22).
    static let defaultMinimumAgeInDays = 3

    private static let excludedPrefixes = ["com.apple.launchd.", OrphanSimulatorTempFinder.namePrefix]
    private static let excludedNames: Set<String> = [".X11-unix", "powerlog"]
    private static let excludedSuffixes = [".sock"]
    private static let secondsPerDay: TimeInterval = 86_400

    // MARK: - Public Properties

    let minimumAge: TimeInterval
    let userID: uid_t
    let appBundleIdentifier: String

    // MARK: - Initializers

    init(minimumAgeInDays: Int = defaultMinimumAgeInDays, userID: uid_t = getuid(), appBundleIdentifier: String) {
        self.minimumAge = TimeInterval(minimumAgeInDays) * Self.secondsPerDay
        self.userID = userID
        self.appBundleIdentifier = appBundleIdentifier
    }

    // MARK: - Public Methods

    /// A busy or denied temporary item is skipped instead of failing the category.
    static func softened(_ result: CleanupItemResult) -> CleanupItemResult {
        let outcome: CleanupItemResult.Outcome

        switch result.outcome {
        case .failed(.inUse): outcome = .skipped(.inUse)
        case .failed(.permissionDenied): outcome = .skipped(.noPermission)
        default: return result
        }

        return CleanupItemResult(
            categoryID: result.categoryID,
            displayPath: result.displayPath,
            bytes: result.bytes,
            outcome: outcome
        )
    }

    /// `clear-temporary-files`: the exclusions first, including the simulator folders that
    /// `clear-orphan-simulator-temp` handles, then the owner, the type and the age.
    /// A folder holding a socket, pipe or device is kept: a tmux or AI agent session may still be
    /// using it, even with an old modification date.
    func decision(for item: TemporaryItem, now: Date) -> TemporaryDecision {
        guard !isExcluded(item.name) else { return .skip(.excluded) }

        guard !item.containsSpecialFiles else { return .skip(.unsupportedFileType) }

        return ownerTypeAndAgeDecision(for: item, now: now)
    }

    /// `clear-orphan-simulator-temp`: the finder already chose the orphans, so only the owner,
    /// the type and the age are checked, which also protects a simulator of an unknown set. The
    /// `syslogsock` inside an orphan is stale, so special files do not count here.
    func simulatorTempDecision(for item: TemporaryItem, now: Date) -> TemporaryDecision {
        ownerTypeAndAgeDecision(for: item, now: now)
    }

    // MARK: - Private Methods

    private func ownerTypeAndAgeDecision(for item: TemporaryItem, now: Date) -> TemporaryDecision {
        guard item.ownerID == userID else { return .skip(.notOwnedByUser) }

        guard item.kind != .other else { return .skip(.unsupportedFileType) }

        guard now.timeIntervalSince(item.newestModification) >= minimumAge else { return .skip(.tooRecent) }

        return .remove
    }

    private func isExcluded(_ name: String) -> Bool {
        Self.excludedNames.contains(name)
            || Self.excludedPrefixes.contains { name.hasPrefix($0) }
            || Self.excludedSuffixes.contains { name.hasSuffix($0) }
            || name.hasPrefix(appBundleIdentifier)
    }

}
