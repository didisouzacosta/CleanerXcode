//
//  RuntimeCatalogFetching.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// Where the catalog of downloadable runtimes comes from (C35).
nonisolated protocol RuntimeCatalogFetching: Sendable {
    /// Cancellation throws; any other failure means the catalog is unavailable now (R6).
    func catalog() async throws -> RuntimeCatalog
}

/// Reads Apple's public catalog (R1): a GET to a fixed HTTPS address, with no credentials nor
/// cookies, on an ephemeral session of its own, with a short timeout and a size limit. Apple sees
/// the Mac's address and the session's default User-Agent, as with any request (R12).
nonisolated struct AppleRuntimeCatalogClient: RuntimeCatalogFetching {

    // MARK: - Public Properties

    static let timeout: TimeInterval = 15
    /// The real catalog is about 600 KB.
    static let maximumBytes = 8 * 1_024 * 1_024

    let url: URL
    /// Read by the tests.
    let session: URLSession

    // MARK: - Initializers

    init(
        url: URL = Constants.runtimeCatalogURL,
        session: URLSession = URLSession(configuration: makeSessionConfiguration())
    ) {
        self.url = url
        self.session = session
    }

    // MARK: - Public Static Methods

    /// Ephemeral, and never sends nor accepts cookies nor keeps credentials.
    static func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        return configuration
    }

    // MARK: - Private Static Methods

    /// Off the caller's actor: the catalog is a property list of hundreds of entries.
    @concurrent
    private static func parse(_ data: Data) async throws -> RuntimeCatalog {
        try RuntimeCatalogParser.catalog(from: data, hostArchitecture: RuntimeCatalogParser.hostArchitecture)
    }

    // MARK: - Public Methods

    func catalog() async throws -> RuntimeCatalog {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false

        let (data, response) = try await session.data(for: request)

        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            http.expectedContentLength <= Int64(Self.maximumBytes),
            data.count <= Self.maximumBytes
        else { throw RuntimeCatalogError.badResponse }

        return try await Self.parse(data)
    }

}
