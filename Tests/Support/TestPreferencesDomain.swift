//
//  TestPreferencesDomain.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// A `UserDefaults` suite with a fixed name owned by one test, removed with its plist afterwards
/// so runs never pile files up in `~/Library/Preferences`.
nonisolated enum TestPreferencesDomain {

    // MARK: - Public Properties

    static let prefix = "didisouzacosta.CleanerXcodeTests."

    // MARK: - Public Methods

    static func defaults(named name: String) -> UserDefaults {
        let domain = prefix + name

        guard let defaults = UserDefaults(suiteName: domain) else {
            preconditionFailure("Could not create the test suite \(domain).")
        }

        defaults.removePersistentDomain(forName: domain)
        return defaults
    }

    static func remove(named name: String) {
        let domain = prefix + name

        UserDefaults.standard.removePersistentDomain(forName: domain)
        // Flushes cfprefsd's pending write first, or it may recreate the empty plist.
        CFPreferencesAppSynchronize(domain as CFString)

        let file = URL(filePath: NSHomeDirectory())
            .appending(path: "Library/Preferences/\(domain).plist", directoryHint: .notDirectory)
        try? FileManager.default.removeItem(at: file)
    }

}
