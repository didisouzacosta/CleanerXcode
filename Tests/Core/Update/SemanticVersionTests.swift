//
//  SemanticVersionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

/// Numeric comparison per component (R16): the old check joined the digits, so `1.0.0` and
/// `0.10.0` were both 100, and `1.0.0` (100) was smaller than `0.11.0` (110).
struct SemanticVersionTests {

    // MARK: - Public Methods

    @Test
    func comparesEachComponentAsANumber() throws {
        let tenth = try #require(SemanticVersion("0.10.0"))
        let ninth = try #require(SemanticVersion("0.9.0"))
        let first = try #require(SemanticVersion("1.0.0"))
        let seventh = try #require(SemanticVersion("0.7.0"))

        #expect(tenth > ninth)
        #expect(first > seventh)
        #expect(first > tenth)
    }

    @Test
    func missingComponentsCountAsZero() throws {
        #expect(try #require(SemanticVersion("1.2")) == #require(SemanticVersion("1.2.0")))
        #expect(try #require(SemanticVersion("1.2.1")) > #require(SemanticVersion("1.2")))
    }

    /// The same version with a newer build is newer; a missing build counts as zero.
    @Test
    func theBuildBreaksTies() throws {
        let older = try #require(SemanticVersion("1.0.0", build: "115"))
        let newer = try #require(SemanticVersion("1.0.0", build: "116"))

        #expect(newer > older)
        #expect(try #require(SemanticVersion("1.0.1", build: "1")) > newer)
        #expect(try #require(SemanticVersion("1.0.0")) < older)
    }

    @Test
    func rejectsWhatIsNotAVersion() {
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("1.x.0") == nil)
        #expect(SemanticVersion("1..0") == nil)
        #expect(SemanticVersion("1.0.0", build: "beta") == nil)
        #expect(SemanticVersion("1.+2.0") == nil)
        #expect(SemanticVersion("1.0.0", build: "+5") == nil)
        #expect(SemanticVersion(" 1.0.0 ") != nil, "Surrounding spaces are ignored.")
        #expect(SemanticVersion("1.0.0\n", build: "7\n") != nil, "And line breaks.")
    }

}
