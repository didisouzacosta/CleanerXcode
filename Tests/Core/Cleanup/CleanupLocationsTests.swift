//
//  CleanupLocationsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CleanupLocationsTests {

    // MARK: - Public Methods

    @Test
    func currentLocationsPointAtTheUserAndSystemFolders() {
        let locations = CleanupLocations.current()

        #expect(locations.home.path() == URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory).path())
        #expect(locations.userTemporary == FileManager.default.temporaryDirectory)
        #expect(locations.systemTemporary.path() == "/private/tmp/")
        #expect(locations.varTemporary.path() == "/private/var/tmp/")
    }

    @Test
    func displayPathReplacesTheHomeFolderWithTilde() {
        let locations = CleanupLocations(
            home: URL(filePath: "/Users/tester", directoryHint: .isDirectory),
            userTemporary: URL(filePath: "/private/var/folders/ab/cd/T", directoryHint: .isDirectory),
            systemTemporary: URL(filePath: "/private/tmp", directoryHint: .isDirectory),
            varTemporary: URL(filePath: "/private/var/tmp", directoryHint: .isDirectory)
        )

        #expect(locations
            .displayPath(for: URL(filePath: "/Users/tester/Library/Developer/X")) == "~/Library/Developer/X")
        #expect(locations.displayPath(for: URL(filePath: "/private/tmp/a")) == "/private/tmp/a")
        #expect(locations.displayPath(for: URL(filePath: "/Users/testerX/a")) == "/Users/testerX/a")
    }

}
