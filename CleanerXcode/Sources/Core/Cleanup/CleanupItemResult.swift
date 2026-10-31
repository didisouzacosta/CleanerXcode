//
//  CleanupItemResult.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated struct CleanupItemResult: Sendable, Hashable {

    // MARK: - Public Properties

    let categoryID: CleanupCategoryID
    /// Path with `~` for the interface only; never sent to analytics or error reports.
    let displayPath: String
    let bytes: Int64
    let outcome: Outcome

    var isFailure: Bool {
        if case .failed = outcome {
            true
        } else {
            false
        }
    }

    // MARK: - Initializers

    /// A missing item or an unsupported root is always recorded as skipped, never as a failure (R6).
    init(categoryID: CleanupCategoryID, displayPath: String, bytes: Int64, outcome: Outcome) {
        self.categoryID = categoryID
        self.displayPath = displayPath
        self.bytes = bytes
        self.outcome = switch outcome {
        case .failed(.notFound): .skipped(.notFound)
        case .failed(.unsupportedRoot): .skipped(.unsupportedRoot)
        default: outcome
        }
    }

    // MARK: - Nested Types

    enum Outcome: Sendable, Hashable {
        case removed
        case trashed
        case skipped(SkipReason)
        case failed(CleanupError)
    }

    enum SkipReason: Sendable, Hashable {
        case notFound
        case inUse
        case noPermission
        case tooRecent
        case notOwnedByUser
        case excluded
        case unsupportedFileType
        case unsupportedRoot
    }

}
