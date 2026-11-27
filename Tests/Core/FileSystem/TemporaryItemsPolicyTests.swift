//
//  TemporaryItemsPolicyTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct TemporaryItemsPolicyTests {

    // MARK: - Private Properties

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let userID: uid_t = 501
    private let policy = TemporaryItemsPolicy(minimumAgeInDays: 3, userID: 501, appBundleIdentifier: "app.Cleaner")

    // MARK: - Public Methods

    @Test(arguments: [
        // Eligible: the user's own, old enough, file, folder or link.
        Row("old-build-folder", owner: 501, kind: .directory, ageInDays: 4, expected: .remove),
        Row("old-file.log", owner: 501, kind: .file, ageInDays: 30, expected: .remove),
        Row("old-link", owner: 501, kind: .symbolicLink, ageInDays: 3.1, expected: .remove),
        // Another owner, too recent or not a file, folder or link.
        Row("root-owned", owner: 0, kind: .directory, ageInDays: 30, expected: .skip(.notOwnedByUser)),
        Row("claude-501", owner: 501, kind: .directory, ageInDays: 0.01, expected: .skip(.tooRecent)),
        Row("almost-old", owner: 501, kind: .file, ageInDays: 2.9, expected: .skip(.tooRecent)),
        Row("pipe", owner: 501, kind: .other, ageInDays: 30, expected: .skip(.unsupportedFileType)),
        // Exclusions, whatever the owner and age.
        Row("com.apple.launchd.zvq9FBiOXN", owner: 501, kind: .directory, ageInDays: 30, expected: .skip(.excluded)),
        Row(".X11-unix", owner: 501, kind: .directory, ageInDays: 30, expected: .skip(.excluded)),
        Row("powerlog", owner: 501, kind: .directory, ageInDays: 30, expected: .skip(.excluded)),
        Row("agent.sock", owner: 501, kind: .file, ageInDays: 30, expected: .skip(.excluded)),
        Row("app.Cleaner", owner: 501, kind: .directory, ageInDays: 30, expected: .skip(.excluded)),
        Row("app.Cleaner.export", owner: 501, kind: .file, ageInDays: 30, expected: .skip(.excluded)),
        Row(
            "com.apple.CoreSimulator.SimDevice.AAAA0000-0000-0000-0000-000000000001",
            owner: 501,
            kind: .directory,
            ageInDays: 30,
            expected: .skip(.excluded)
        ),
    ])
    func decidesEachTemporaryItem(_ row: Row) {
        let item = TemporaryItem(
            name: row.name,
            ownerID: row.owner,
            kind: row.kind,
            newestModification: now.addingTimeInterval(-row.ageInDays * 86_400)
        )

        #expect(policy.decision(for: item, now: now) == row.expected)
    }

    /// A tmux or agent socket keeps an old modification date while the session is alive.
    @Test
    func anOldFolderHoldingASocketOrPipeIsKept() {
        let live = TemporaryItem(
            name: "tmux-501",
            ownerID: userID,
            kind: .directory,
            newestModification: now.addingTimeInterval(-30 * 86_400),
            containsSpecialFiles: true
        )

        #expect(policy.decision(for: live, now: now) == .skip(.unsupportedFileType))
        #expect(policy.simulatorTempDecision(for: live, now: now) == .remove, "An orphan's socket is stale.")
    }

    @Test
    func simulatorTempOnlyChecksTheOwnerTheTypeAndTheAge() {
        let name = "com.apple.CoreSimulator.SimDevice.AAAA0000-0000-0000-0000-000000000001"
        let old = TemporaryItem(
            name: name,
            ownerID: userID,
            kind: .directory,
            newestModification: now.addingTimeInterval(-5 * 86_400)
        )
        let recent = TemporaryItem(name: name, ownerID: userID, kind: .directory, newestModification: now)
        let foreign = TemporaryItem(name: name, ownerID: 0, kind: .directory, newestModification: .distantPast)

        #expect(policy.simulatorTempDecision(for: old, now: now) == .remove)
        #expect(policy.simulatorTempDecision(for: recent, now: now) == .skip(.tooRecent))
        #expect(policy.simulatorTempDecision(for: foreign, now: now) == .skip(.notOwnedByUser))
    }

    @Test
    func busyOrDeniedItemsAreSkippedInsteadOfFailingTheCategory() {
        let busy = result(.failed(.inUse))
        let denied = result(.failed(.permissionDenied))
        let other = result(.failed(.unsafePath))
        let removed = result(.removed)

        #expect(TemporaryItemsPolicy.softened(busy).outcome == .skipped(.inUse))
        #expect(TemporaryItemsPolicy.softened(denied).outcome == .skipped(.noPermission))
        #expect(TemporaryItemsPolicy.softened(other) == other)
        #expect(TemporaryItemsPolicy.softened(removed) == removed)
    }

    @Test
    func theMinimumAgeComesFromTheSettingsInDays() {
        #expect(TemporaryItemsPolicy(minimumAgeInDays: 7, userID: 1, appBundleIdentifier: "a").minimumAge == 7 * 86_400)
        #expect(TemporaryItemsPolicy.defaultMinimumAgeInDays == 3)
    }

    // MARK: - Private Methods

    private func result(_ outcome: CleanupItemResult.Outcome) -> CleanupItemResult {
        CleanupItemResult(categoryID: .clearTemporaryFiles, displayPath: "/private/tmp/x", bytes: 0, outcome: outcome)
    }

    // MARK: - Nested Types

    nonisolated struct Row: Sendable, CustomTestStringConvertible {

        // MARK: - Public Properties

        let name: String
        let owner: uid_t
        let kind: TemporaryItem.Kind
        let ageInDays: Double
        let expected: TemporaryDecision

        var testDescription: String {
            name
        }

        // MARK: - Initializers

        init(_ name: String, owner: uid_t, kind: TemporaryItem.Kind, ageInDays: Double, expected: TemporaryDecision) {
            self.name = name
            self.owner = owner
            self.kind = kind
            self.ageInDays = ageInDays
            self.expected = expected
        }

    }

}
