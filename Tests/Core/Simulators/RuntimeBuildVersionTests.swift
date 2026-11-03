//
//  RuntimeBuildVersionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

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

}
