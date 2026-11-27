//
//  SemanticVersion.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// A version compared per numeric component (R16), so `0.10.0` is newer than `0.9.0`; missing
/// components count as zero, and the build number breaks ties.
nonisolated struct SemanticVersion: Comparable, Sendable {

    // MARK: - Private Properties

    private let components: [Int]
    private let build: Int

    // MARK: - Initializers

    /// `nil` unless every component, and the build when given, is made of ASCII digits only.
    init?(_ version: String, build: String? = nil) {
        let parts = version.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false)
            .map(String.init)
        let numbers = parts.compactMap(Self.number)

        guard numbers.count == parts.count else { return nil }

        let buildNumber: Int

        if let build {
            guard let number = Self.number(build.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }

            buildNumber = number
        } else {
            buildNumber = 0
        }

        self.components = numbers
        self.build = buildNumber
    }

    // MARK: - Private Methods

    /// Digits only: no sign, no spaces.
    private static func number(_ text: String) -> Int? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }

        return Int(text)
    }

    // MARK: - Public Methods

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let length = max(lhs.components.count, rhs.components.count)

        for index in 0..<length {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0

            if left != right {
                return left < right
            }
        }

        return lhs.build < rhs.build
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

}
