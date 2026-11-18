//
//  MainAppLoginItemTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import ServiceManagement
import Testing
@testable import CleanerXcode

/// A fake service stands in for `SMAppService.mainApp`, so no test registers a real login item.
@MainActor
struct MainAppLoginItemTests {

    // MARK: - Public Methods

    @Test(arguments: [
        (SMAppService.Status.enabled, LoginItemStatus.enabled),
        (.notRegistered, .notRegistered),
        (.requiresApproval, .requiresApproval),
        (.notFound, .notFound),
    ])
    func mapsTheServiceStatus(service: SMAppService.Status, expected: LoginItemStatus) {
        let loginItem = MainAppLoginItem(service: AppServiceSpy(status: service))

        #expect(loginItem.status == expected)
        #expect(loginItem.isEnabled == (expected == .enabled))
    }

    @Test
    func registersAndUnregisters() throws {
        let service = AppServiceSpy(status: .notRegistered)
        let loginItem = MainAppLoginItem(service: service)

        try loginItem.setEnabled(true)
        try loginItem.setEnabled(false)

        #expect(service.calls == ["register", "unregister"])
    }

    @Test
    func aFailedRegistrationIsThrownAsACleanupError() {
        let service = AppServiceSpy(status: .notRegistered, failure: CocoaError(.fileWriteNoPermission))

        #expect(throws: CleanupError.permissionDenied) { try MainAppLoginItem(service: service).setEnabled(true) }
    }

    // MARK: - Nested Types

    private final class AppServiceSpy: AppServiceControlling {

        // MARK: - Public Properties

        let status: SMAppService.Status

        private(set) var calls: [String] = []

        // MARK: - Private Properties

        private let failure: (any Error)?

        // MARK: - Initializers

        init(status: SMAppService.Status, failure: (any Error)? = nil) {
            self.status = status
            self.failure = failure
        }

        // MARK: - Public Methods

        func register() throws {
            calls.append("register")

            if let failure {
                throw failure
            }
        }

        func unregister() throws {
            calls.append("unregister")
        }

    }

}
