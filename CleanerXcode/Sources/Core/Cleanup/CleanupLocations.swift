//
//  CleanupLocations.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Base folders every catalog root is built from. Injectable so tests point at a folder they own.
nonisolated struct CleanupLocations: Sendable, Hashable {

    // MARK: - Public Properties

    let home: URL
    /// `$TMPDIR`, `/var/folders/<x>/<y>/T/`.
    let userTemporary: URL
    let systemTemporary: URL
    let varTemporary: URL

    // MARK: - Initializers

    init(home: URL, userTemporary: URL, systemTemporary: URL, varTemporary: URL) {
        let urls = [home, userTemporary, systemTemporary, varTemporary]

        precondition(
            urls.allSatisfy { $0.path(percentEncoded: false).hasPrefix("/") },
            "CleanupLocations only accepts absolute paths."
        )

        self.home = home
        self.userTemporary = userTemporary
        self.systemTemporary = systemTemporary
        self.varTemporary = varTemporary
    }

    // MARK: - Public Methods

    static func current() -> CleanupLocations {
        CleanupLocations(
            home: URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory),
            userTemporary: FileManager.default.temporaryDirectory,
            systemTemporary: URL(filePath: "/private/tmp", directoryHint: .isDirectory),
            varTemporary: URL(filePath: "/private/var/tmp", directoryHint: .isDirectory)
        )
    }

    /// For the interface only: never sent to analytics or error reports.
    func displayPath(for url: URL) -> String {
        let path = url.path(percentEncoded: false)
        let homePath = home.path(percentEncoded: false)
        let homePrefix = homePath.hasSuffix("/") ? homePath : homePath + "/"

        if path == homePrefix || path + "/" == homePrefix {
            return "~"
        }

        guard path.hasPrefix(homePrefix) else { return path }

        return "~/" + path.dropFirst(homePrefix.count)
    }

}
