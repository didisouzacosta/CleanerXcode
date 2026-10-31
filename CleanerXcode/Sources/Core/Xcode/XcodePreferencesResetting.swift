//
//  XcodePreferencesResetting.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated protocol XcodePreferencesResetting: Sendable {
    func reset() throws
}

/// Resets a preferences domain through `cfprefsd`, in place of `defaults delete` (F10). Dangerous:
/// the Xcode domain holds the custom DerivedData location, behaviors and window state, so the
/// interface blocks it while Xcode runs (R5).
nonisolated struct UserDefaultsPreferencesResetter: XcodePreferencesResetting {

    // MARK: - Public Properties

    static let xcodeDomain = "com.apple.dt.Xcode"

    let domain: String

    // MARK: - Initializers

    init(domain: String = xcodeDomain) {
        self.domain = domain
    }

    // MARK: - Public Methods

    /// Throws when values are still there afterwards, so a failed reset never reads as a success.
    func reset() throws {
        let defaults = UserDefaults.standard

        defaults.removePersistentDomain(forName: domain)

        guard defaults.persistentDomain(forName: domain)?.isEmpty ?? true else {
            throw CleanupError.unknown(domain: "XcodePreferences", code: 1)
        }
    }

}
