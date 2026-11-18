//
//  UpdatePreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

#if DEBUG
    import Foundation

    /// The update check without the network: with or without a newer version.
    enum UpdatePreview {

        // MARK: - Public Methods

        static func makeViewModel(hasUpdate: Bool = false, supportsUserChecks: Bool = false) -> UpdateViewModel {
            UpdateViewModel(
                updater: PreviewSoftwareUpdater(
                    newerVersion: hasUpdate ? "1.0.1" : nil,
                    supportsUserChecks: supportsUserChecks
                ),
                analytics: NullAnalytics(),
                errorReporter: NullErrorReporter()
            )
        }

    }

    private final class PreviewSoftwareUpdater: SoftwareUpdating {

        // MARK: - Public Properties

        let supportsUserChecks: Bool

        var automaticallyChecksForUpdates = true

        // MARK: - Private Properties

        private let version: String?

        // MARK: - Initializers

        init(newerVersion: String?, supportsUserChecks: Bool) {
            self.version = newerVersion
            self.supportsUserChecks = supportsUserChecks
        }

        // MARK: - Public Methods

        func newerVersion() -> String? {
            version
        }

        func presentUpdate() {}

        func checkForUpdates() {}

        func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
            automaticallyChecksForUpdates = isOn
        }

    }
#endif
