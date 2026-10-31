//
//  UserDefaultsPreferencesResetterTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Only ever resets domains the test creates, through `TestPreferencesDomain`; the real Xcode
/// domain is never touched. The names are fixed and distinct per test (they run in parallel).
struct UserDefaultsPreferencesResetterTests {

    // MARK: - Public Methods

    @Test
    func removesEveryValueOfItsDomainAndNothingElse() throws {
        let domain = TestPreferencesDomain.prefix + "reset.removesEveryValue"
        let neighbor = TestPreferencesDomain.prefix + "keep.neighbor"

        UserDefaults.standard.setPersistentDomain(
            ["IDECustomDerivedDataLocation": "/Volumes/Fast/DerivedData", "DVTTextShowLineNumbers": true],
            forName: domain
        )
        UserDefaults.standard.setPersistentDomain(["kept": true], forName: neighbor)

        defer {
            TestPreferencesDomain.remove(named: "reset.removesEveryValue")
            TestPreferencesDomain.remove(named: "keep.neighbor")
        }

        try UserDefaultsPreferencesResetter(domain: domain).reset()

        #expect(UserDefaults.standard.persistentDomain(forName: domain)?.isEmpty ?? true)
        #expect(UserDefaults.standard.persistentDomain(forName: neighbor)?["kept"] as? Bool == true)
    }

    @Test
    func resettingAnEmptyDomainSucceeds() throws {
        let domain = TestPreferencesDomain.prefix + "reset.empty"

        defer { TestPreferencesDomain.remove(named: "reset.empty") }

        try UserDefaultsPreferencesResetter(domain: domain).reset()

        #expect(UserDefaults.standard.persistentDomain(forName: domain)?.isEmpty ?? true)
    }

    @Test
    func targetsTheXcodeDomainByDefault() {
        #expect(UserDefaultsPreferencesResetter.xcodeDomain == "com.apple.dt.Xcode")
        #expect(UserDefaultsPreferencesResetter().domain == "com.apple.dt.Xcode")
    }

}
