//
//  RuntimeBuildVersion.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// The value of `xcodebuild -buildVersion`: one to three groups of ASCII digits separated by dots,
/// such as "18", "18.0" or "26.1.1". Any other text builds nothing, so it can never become another
/// argument such as "-exportPath" (C30, R2).
nonisolated struct RuntimeBuildVersion: Sendable, Hashable {

    // MARK: - Public Properties

    let rawValue: String

    // MARK: - Initializers

    init?(_ text: String) {
        let groups = text.split(separator: ".", omittingEmptySubsequences: false)
        let digits = UInt8(ascii: "0")...UInt8(ascii: "9")

        guard (1...3).contains(groups.count) else { return nil }

        // UTF-8 bytes, not characters: "1\u{301}" or other scripts' digits never pass.
        guard groups.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy(digits.contains) }) else { return nil }

        rawValue = text
    }

}
