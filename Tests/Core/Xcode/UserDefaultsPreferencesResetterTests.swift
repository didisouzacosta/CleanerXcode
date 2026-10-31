//
//  UserDefaultsPreferencesResetterTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Only ever resets domains the test creates; the real Xcode domain is never touched. The names
/// are fixed and distinct per test (they run in parallel), and their plist files are removed
/// afterwards, so no run leaves anything in `~/Library/Preferences`.
struct UserDefaultsPreferencesResetterTests {

    // MARK: - Public Methods

    @Test
    func removesEveryValueOfItsDomainAndNothingElse() throws {
        let domain = "didisouzacosta.CleanerXcodeTests.reset.removesEveryValue"
        let neighbor = "didisouzacosta.CleanerXcodeTests.keep.neighbor"

        UserDefaults.standard.setPersistentDomain(
            ["IDECustomDerivedDataLocation": "/Volumes/Fast/DerivedData", "DVTTextShowLineNumbers": true],
            forName: domain
        )
        UserDefaults.standard.setPersistentDomain(["kept": true], forName: neighbor)

        defer {
            removeTestDomain(domain)
            removeTestDomain(neighbor)
        }

        try UserDefaultsPreferencesResetter(domain: domain).reset()

        #expect(UserDefaults.standard.persistentDomain(forName: domain)?.isEmpty ?? true)
        #expect(UserDefaults.standard.persistentDomain(forName: neighbor)?["kept"] as? Bool == true)
    }

    @Test
    func resettingAnEmptyDomainSucceeds() throws {
        let domain = "didisouzacosta.CleanerXcodeTests.reset.empty"

        defer { removeTestDomain(domain) }

        try UserDefaultsPreferencesResetter(domain: domain).reset()

        #expect(UserDefaults.standard.persistentDomain(forName: domain)?.isEmpty ?? true)
    }

    @Test
    func targetsTheXcodeDomainByDefault() {
        #expect(UserDefaultsPreferencesResetter.xcodeDomain == "com.apple.dt.Xcode")
        #expect(UserDefaultsPreferencesResetter().domain == "com.apple.dt.Xcode")
    }

    // MARK: - Private Methods

    /// Only domains with the tests' own prefix: removing a domain leaves an empty plist behind.
    private func removeTestDomain(_ domain: String) {
        precondition(domain.hasPrefix("didisouzacosta.CleanerXcodeTests."), "Tests only remove their own domains.")

        UserDefaults.standard.removePersistentDomain(forName: domain)
        // Flushes cfprefsd's pending write first, or it recreates the empty plist after the removal.
        CFPreferencesAppSynchronize(domain as CFString)

        let file = URL(filePath: NSHomeDirectory())
            .appending(path: "Library/Preferences/\(domain).plist", directoryHint: .notDirectory)
        try? FileManager.default.removeItem(at: file)
    }

}
