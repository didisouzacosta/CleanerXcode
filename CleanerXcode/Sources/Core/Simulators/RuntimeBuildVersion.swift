//
//  RuntimeBuildVersion.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation

/// The value of `xcodebuild -buildVersion`: one to three groups of ASCII digits separated by dots,
/// such as "18", "18.0" or "26.1.1". Any other text builds nothing, so it can never become another
/// argument such as "-exportPath" (C30, R2). Equality is the text's, because "26" and "26.0" are
/// different arguments; `compareNumerically` orders versions as numbers (C35).
nonisolated struct RuntimeBuildVersion: Sendable, Hashable {

    // MARK: - Public Properties

    let rawValue: String

    /// "26.4.1" → [26, 4, 1]. A group too large for `Int` counts as `Int.max`.
    var numericComponents: [Int] {
        rawValue.split(separator: ".").map { Int($0) ?? .max }
    }

    // MARK: - Initializers

    init?(_ text: String) {
        let groups = text.split(separator: ".", omittingEmptySubsequences: false)
        let digits = UInt8(ascii: "0")...UInt8(ascii: "9")

        guard (1...3).contains(groups.count) else { return nil }

        // UTF-8 bytes, not characters: "1\u{301}" or other scripts' digits never pass.
        guard groups.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy(digits.contains) }) else { return nil }

        rawValue = text
    }

    // MARK: - Public Methods

    /// As numbers, group by group, with missing trailing groups read as 0: "26" = "26.0" = "26.0.0",
    /// "26.4.1" > "26.4", "26.10" > "26.9".
    static func compareNumerically(_ lhs: RuntimeBuildVersion, _ rhs: RuntimeBuildVersion) -> ComparisonResult {
        let left = lhs.numericComponents
        let right = rhs.numericComponents

        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue != rightValue {
                return leftValue < rightValue ? .orderedAscending : .orderedDescending
            }
        }

        return .orderedSame
    }

}
