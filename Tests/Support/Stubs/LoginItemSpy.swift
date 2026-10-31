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
    /// What `SMAppService` reports after a failed attempt, such as `.requiresApproval`.
    private let statusAfterFailure: LoginItemStatus?

    // MARK: - Initializers

    init(status: LoginItemStatus, failure: CleanupError? = nil, statusAfterFailure: LoginItemStatus? = nil) {
        self.status = status
        self.failure = failure
        self.statusAfterFailure = statusAfterFailure
    }

    // MARK: - Public Methods

    func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled)

        if let failure {
            status = statusAfterFailure ?? status
            throw failure
        }

        status = enabled ? .enabled : .notRegistered
    }

}
