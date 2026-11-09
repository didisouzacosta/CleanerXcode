//
//  RuntimeBuildVersionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Only plain versions reach `-buildVersion`, so no text can become another argument (C30, R2).
struct RuntimeBuildVersionTests {

    // MARK: - Public Methods

    @Test(arguments: ["18", "18.0", "26.1.1", "0"])
    func acceptsOneToThreeGroupsOfDigits(text: String) throws {
        let version = try #require(RuntimeBuildVersion(text))

        #expect(version.rawValue == text)
    }

    @Test(arguments: ["", "18.", ".1", "1..2", "1.2.3.4", "18a", " 18", "18.0 ", "-exportPath", "1\u{301}", "١٨"])
    func rejectsEverythingElse(text: String) {
        #expect(RuntimeBuildVersion(text) == nil)
    }

    @Test
    func readsItsNumericComponents() throws {
        #expect(try #require(RuntimeBuildVersion("26.4.1")).numericComponents == [26, 4, 1])
        #expect(try #require(RuntimeBuildVersion("27")).numericComponents == [27])
        #expect(try #require(RuntimeBuildVersion("026.10")).numericComponents == [26, 10])
    }

    /// Versions compare as numbers, with trailing zeros ignored (C35, R3).
    @Test(arguments: [
        ("26", "26.0", ComparisonResult.orderedSame),
        ("26.0", "26.0.0", .orderedSame),
        ("26", "26.0.0", .orderedSame),
        ("26.4.1", "26.4", .orderedDescending),
        ("27.0", "26.5", .orderedDescending),
        ("26.10", "26.9", .orderedDescending),
        ("26.5", "27.2", .orderedAscending),
        ("9.3", "10", .orderedAscending),
    ])
    func comparesNumerically(lhs: String, rhs: String, expected: ComparisonResult) throws {
        let left = try #require(RuntimeBuildVersion(lhs))
        let right = try #require(RuntimeBuildVersion(rhs))

        #expect(RuntimeBuildVersion.compareNumerically(left, right) == expected)
        #expect(RuntimeBuildVersion.compareNumerically(right, left) == mirrored(expected))
    }

    /// Equality stays the text's: "26" and "26.0" are two arguments for `xcodebuild`.
    @Test
    func equalityIsStillTheText() throws {
        #expect(try #require(RuntimeBuildVersion("26")) != RuntimeBuildVersion("26.0"))
    }

    // MARK: - Private Methods

    private func mirrored(_ result: ComparisonResult) -> ComparisonResult {
        switch result {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }

}
