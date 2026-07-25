import Foundation

protocol XcodePreferencesResetting: Sendable {
    func reset(_ domain: String) async throws
}

actor UserDefaultsXcodePreferencesResetter: XcodePreferencesResetting {

    // MARK: - Private Properties

    private let userDefaults: UserDefaults

    // MARK: - Initializer

    init(_ userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    func reset(_ domain: String) {
        userDefaults.removePersistentDomain(forName: domain)
    }
}
