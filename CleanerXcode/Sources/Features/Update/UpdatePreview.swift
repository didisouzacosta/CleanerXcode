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

        static func makeViewModel(hasUpdate: Bool = false) -> UpdateViewModel {
            let checker: any VersionChecking = hasUpdate ? PreviewVersionChecker() : InertVersionChecker()

            return UpdateViewModel(
                currentVersion: "1.0.0",
                currentBuild: "115",
                checker: checker,
                analytics: NullAnalytics(),
                errorReporter: NullErrorReporter()
            )
        }

    }

    nonisolated private struct PreviewVersionChecker: VersionChecking {

        // MARK: - Public Methods

        func latestVersion() throws -> Version {
            guard let url = URL(string: "https://example.invalid/CleanerXcode.dmg") else {
                throw RemoteVersionChecker.CheckError.notConfigured
            }

            return Version(version: "1.0.1", build: "116", downloadURL: url)
        }

    }
#endif
