//
//  RuntimeDownloadChoiceTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Testing
@testable import CleanerXcode

/// The platforms and versions chosen in the "Download runtimes" sheet (C35, R4, AC8).
struct RuntimeDownloadChoiceTests {

    // MARK: - Public Methods

    @Test
    func choosingAVersionSelectsThePlatform() throws {
        var choice = RuntimeDownloadChoice()

        try choice.select(version("26.5"), for: .iOS)

        #expect(choice.selected == [.iOS])
        #expect(choice.versions.mapValues(\.rawValue) == [.iOS: "26.5"])
    }

    /// One version per platform: a new choice replaces the last one.
    @Test
    func oneVersionPerPlatform() throws {
        var choice = RuntimeDownloadChoice()

        try choice.select(version("26.5"), for: .iOS)
        try choice.select(version("26.0"), for: .iOS)
        try choice.select(version("26.5"), for: .watchOS)

        #expect(choice.versions.mapValues(\.rawValue) == [.iOS: "26.0", .watchOS: "26.5"])
        #expect(choice.orderedSelection == [.iOS, .watchOS])
    }

    /// Choosing Xcode's version drops the earlier one and still selects the platform.
    @Test
    func choosingXcodesVersionDropsTheEarlierOne() throws {
        var choice = RuntimeDownloadChoice()

        try choice.select(version("26.5"), for: .iOS)
        choice.toggle(.iOS)
        choice.select(nil, for: .iOS)

        #expect(choice.selected == [.iOS])
        #expect(choice.versions.isEmpty)

        choice.select(nil, for: .tvOS)

        #expect(choice.selected == [.iOS, .tvOS])
    }

    /// Unchecking a platform keeps its version, so checking it again restores it.
    @Test
    func uncheckingKeepsTheChosenVersion() throws {
        var choice = RuntimeDownloadChoice()

        try choice.select(version("26.5"), for: .iOS)
        choice.toggle(.iOS)

        #expect(choice.selected.isEmpty)
        #expect(choice.versions.mapValues(\.rawValue) == [.iOS: "26.5"])

        choice.toggle(.iOS)

        #expect(choice.selected == [.iOS])
        #expect(choice.versions.mapValues(\.rawValue) == [.iOS: "26.5"])
    }

    // MARK: - Private Methods

    private func version(_ text: String) throws -> RuntimeBuildVersion {
        try #require(RuntimeBuildVersion(text))
    }

}
