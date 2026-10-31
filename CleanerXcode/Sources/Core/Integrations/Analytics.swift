//
//  Analytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 16/03/25.
//

protocol Analytics {
    func log(_ event: AnalyticsEvent)
}

/// Stable product events. Names use `[a-z0-9_]` and properties only carry enumerated values,
/// counts and buckets: never paths, file names, simulator names, UDIDs or exact sizes.
enum AnalyticsEvent {

    // MARK: - Cases

    case cleaner(categories: [String], result: CleanupResultKind, freedBytes: Int64)
    case cleanerPartialFailure(failedCategories: [String], errorKinds: [CleanupErrorKind])
    case simulatorDeleted(count: Int, reason: SimulatorDeletionReason)
    case simulatorUnavailableDeleted(count: Int)
    case runtimeDeleted(count: Int)
    case social(Social)
    case donate
    case updateOpened

    // MARK: - Public Properties

    var name: String {
        switch self {
        case .cleaner: "cleaner"
        case .cleanerPartialFailure: "cleaner_partial_failure"
        case .simulatorDeleted: "simulator_deleted"
        case .simulatorUnavailableDeleted: "simulator_unavailable_deleted"
        case .runtimeDeleted: "runtime_deleted"
        case .social: "social"
        case .donate: "donate"
        case .updateOpened: "update_opened"
        }
    }

    var properties: [String: Any] {
        switch self {
        case let .cleaner(categories, result, freedBytes):
            [
                "categories": categories.joined(separator: ", "),
                "result": result.rawValue,
                "freed_bucket": Self.freedBucket(for: freedBytes),
            ]

        case let .cleanerPartialFailure(failedCategories, errorKinds):
            [
                "failed_categories": failedCategories.joined(separator: ", "),
                "error_kinds": Set(errorKinds.map(\.rawValue)).sorted().joined(separator: ", "),
            ]

        case let .simulatorDeleted(count, reason):
            ["count": count, "reason": reason.rawValue]

        case let .simulatorUnavailableDeleted(count), let .runtimeDeleted(count):
            ["count": count]

        case let .social(social):
            ["platform": social.rawValue]

        case .donate, .updateOpened:
            [:]
        }
    }

    // MARK: - Private Methods

    private static func freedBucket(for bytes: Int64) -> String {
        let gigabyte: Int64 = 1_000_000_000

        switch bytes {
        case ..<gigabyte: return "<1GB"
        case ..<(10 * gigabyte): return "1-10GB"
        case ..<(50 * gigabyte): return "10-50GB"
        default: return ">50GB"
        }
    }

    // MARK: - Nested Types

    enum Social: String {
        case xPlatform = "x"
        case github
        case linkedin
    }

    enum CleanupResultKind: String {
        case success
        case partialFailure = "partial_failure"
        case failure
        case cancelled
    }

    enum CleanupErrorKind: String {
        case permission
        case inUse = "in_use"
        case toolUnavailable = "tool_unavailable"
        case timeout
        case commandFailed = "command_failed"
        case other
    }

    enum SimulatorDeletionReason: String {
        case duplicate
        case manual
    }

}
