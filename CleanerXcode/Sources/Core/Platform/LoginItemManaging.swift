//
//  LoginItemManaging.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import ServiceManagement

enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case notRegistered
    /// The user must allow it in System Settings > General > Login Items.
    case requiresApproval
    case notFound
}

protocol LoginItemManaging {
    var status: LoginItemStatus { get }
    var isEnabled: Bool { get }

    func setEnabled(_ enabled: Bool) throws
}

/// The part of `SMAppService` the app uses, so tests never register a real login item.
protocol AppServiceControlling: AnyObject {
    var status: SMAppService.Status { get }

    func register() throws
    func unregister() throws
}

extension SMAppService: AppServiceControlling {}

/// "Open at login" through `SMAppService.mainApp`, in place of the LaunchAtLogin package (F12, R15).
struct MainAppLoginItem: LoginItemManaging {

    // MARK: - Public Properties

    var status: LoginItemStatus {
        switch service.status {
        case .enabled: .enabled
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    var isEnabled: Bool {
        status == .enabled
    }

    // MARK: - Private Properties

    private let service: any AppServiceControlling

    // MARK: - Initializers

    init(service: any AppServiceControlling = SMAppService.mainApp) {
        self.service = service
    }

    // MARK: - Public Methods

    func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            throw CleanupError(error)
        }
    }

}
