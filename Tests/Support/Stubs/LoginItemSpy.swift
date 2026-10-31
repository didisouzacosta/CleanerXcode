//
//  LoginItemSpy.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

@testable import CleanerXcode

/// Records the requests and never touches the real login items.
final class LoginItemSpy: LoginItemManaging {

    // MARK: - Public Properties

    private(set) var status: LoginItemStatus
    private(set) var requests: [Bool] = []

    var isEnabled: Bool {
        status == .enabled
    }

    // MARK: - Private Properties

    private let failure: CleanupError?

    // MARK: - Initializers

    init(status: LoginItemStatus, failure: CleanupError? = nil) {
        self.status = status
        self.failure = failure
    }

    // MARK: - Public Methods

    func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled)

        if let failure {
            throw failure
        }

        status = enabled ? .enabled : .notRegistered
    }

}
