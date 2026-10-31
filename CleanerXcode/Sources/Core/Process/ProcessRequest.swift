//
//  ProcessRequest.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// A command run without a shell: an absolute executable and its arguments as an array.
nonisolated struct ProcessRequest: Sendable, Hashable {

    // MARK: - Public Properties

    /// `simctl list`, `delete`, `shutdown` and the other quick commands.
    static let defaultTimeout: Duration = .seconds(60)
    static let eraseAllTimeout: Duration = .seconds(600)
    static let runtimeDeleteTimeout: Duration = .seconds(1_800)

    let executableURL: URL
    let arguments: [String]
    let timeout: Duration

    // MARK: - Initializers

    init(executableURL: URL, arguments: [String], timeout: Duration) {
        precondition(
            executableURL.path(percentEncoded: false).hasPrefix("/"),
            "The executable must be an absolute path."
        )

        self.executableURL = executableURL
        self.arguments = arguments
        self.timeout = timeout
    }

    // MARK: - Public Methods

    static func xcrun(_ arguments: [String], timeout: Duration = defaultTimeout) -> ProcessRequest {
        ProcessRequest(executableURL: URL(filePath: "/usr/bin/xcrun"), arguments: arguments, timeout: timeout)
    }

}
