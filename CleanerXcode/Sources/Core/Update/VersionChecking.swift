//
//  VersionChecking.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Where the latest published version comes from (`version.json`).
nonisolated protocol VersionChecking: Sendable {
    func latestVersion() async throws -> Version
}

/// Reads `version.json` with a short timeout; any failure is thrown and the caller stays silent.
nonisolated struct RemoteVersionChecker: VersionChecking {

    // MARK: - Public Properties

    static let timeout: TimeInterval = 10

    // MARK: - Private Properties

    private let url: URL?
    private let session: URLSession

    // MARK: - Initializers

    init(url: URL?, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    // MARK: - Public Methods

    func latestVersion() async throws -> Version {
        guard let url else { throw CheckError.notConfigured }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CheckError.badResponse
        }

        return try JSONDecoder().decode(Version.self, from: data)
    }

    // MARK: - Nested Types

    enum CheckError: Error, Equatable {
        /// No `VERSION_FILE_URL` in the build.
        case notConfigured
        case badResponse
    }

}

/// For the test host and previews: never reaches the network.
nonisolated struct InertVersionChecker: VersionChecking {

    // MARK: - Public Methods

    func latestVersion() throws -> Version {
        throw RemoteVersionChecker.CheckError.notConfigured
    }

}
