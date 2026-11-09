//
//  AppleRuntimeCatalogClientTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Synchronization
import Testing
@testable import CleanerXcode

/// Reading Apple's catalog of downloadable runtimes (C35, R1, AC1) through a stub `URLProtocol` on an
/// ephemeral session: nothing reaches the network. Serialized because the stub's answer is shared.
@Suite(.serialized)
struct AppleRuntimeCatalogClientTests {

    // MARK: - Public Methods

    @Test
    func readsTheCatalogWithAShortTimeoutAndWithoutTheLocalCache() async throws {
        let body = try SimulatorRuntimeIndexFixture.data()

        CatalogStub.answer(status: 200, body: body)

        let catalog = try await client().catalog()
        let request = try #require(CatalogStub.lastRequest)

        #expect(try catalog == (RuntimeCatalogParser.catalog(
            from: body,
            hostArchitecture: RuntimeCatalogParser.hostArchitecture
        )))
        #expect(request.url == Constants.runtimeCatalogURL)
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 15)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(!request.httpShouldHandleCookies)
    }

    /// N1: no cookie is ever sent nor accepted, by the session and by each request.
    @Test
    func cookiesAreNeverSentNorAccepted() {
        let configuration = AppleRuntimeCatalogClient().session.configuration
        let ownConfiguration = AppleRuntimeCatalogClient.makeSessionConfiguration()

        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.httpCookieAcceptPolicy == .never)
        #expect(!ownConfiguration.httpShouldSetCookies)
        #expect(ownConfiguration.httpCookieAcceptPolicy == .never)
        #expect(ownConfiguration.urlCredentialStorage == nil)
    }

    /// The public catalog, over HTTPS, at a fixed address.
    @Test
    func theCatalogAddressIsApplesPublicCatalog() {
        #expect(
            Constants.runtimeCatalogURL.absoluteString
                == "https://devimages-cdn.apple.com/downloads/xcode/simulators/index2.dvtdownloadableindex"
        )
        #expect(AppleRuntimeCatalogClient().url == Constants.runtimeCatalogURL)
    }

    @Test(arguments: [500, 404, 304, 199])
    func anAnswerOtherThan2xxFails(status: Int) async throws {
        try CatalogStub.answer(status: status, body: SimulatorRuntimeIndexFixture.data())

        await #expect(throws: RuntimeCatalogError.badResponse) {
            try await client().catalog()
        }
    }

    @Test
    func aBodyLargerThanTheLimitFails() async {
        CatalogStub.answer(status: 200, body: Data(count: AppleRuntimeCatalogClient.maximumBytes + 1))

        await #expect(throws: RuntimeCatalogError.badResponse) {
            try await client().catalog()
        }
    }

    @Test
    func aDeclaredLengthLargerThanTheLimitFails() async throws {
        try CatalogStub.answer(
            status: 200,
            body: SimulatorRuntimeIndexFixture.data(),
            headers: ["Content-Length": "\(AppleRuntimeCatalogClient.maximumBytes + 1)"]
        )

        await #expect(throws: RuntimeCatalogError.badResponse) {
            try await client().catalog()
        }
    }

    @Test
    func anUnreadableBodyIsMalformed() async {
        CatalogStub.answer(status: 200, body: Data("<html>Not found</html>".utf8))

        await #expect(throws: RuntimeCatalogError.malformed) {
            try await client().catalog()
        }
    }

    /// Its own ephemeral session: no shared cookies nor credentials, nothing kept on disk.
    @Test
    func theDefaultSessionIsEphemeralAndItsOwn() {
        let session = AppleRuntimeCatalogClient().session

        #expect(session !== URLSession.shared)
        #expect(session.configuration.httpCookieStorage !== HTTPCookieStorage.shared)
        #expect(session.configuration.urlCredentialStorage !== URLCredentialStorage.shared)
        #expect(session.configuration.urlCache !== URLCache.shared)
        #expect(AppleRuntimeCatalogClient.timeout == 15)
        #expect(AppleRuntimeCatalogClient.maximumBytes == 8 * 1_024 * 1_024)
    }

    // MARK: - Private Methods

    private func client() -> AppleRuntimeCatalogClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CatalogStub.self]

        return AppleRuntimeCatalogClient(session: URLSession(configuration: configuration))
    }

}

nonisolated private final class CatalogStub: URLProtocol {

    // MARK: - Public Properties

    static var lastRequest: URLRequest? {
        state.withLock { $0.lastRequest }
    }

    // MARK: - Private Properties

    private static let state = Mutex(State())

    // MARK: - Public Methods

    static func answer(status: Int, body: Data, headers: [String: String] = [:]) {
        state.withLock { state in
            state.answer = Answer(status: status, body: body, headers: headers)
            state.lastRequest = nil
        }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let answer = Self.state.withLock { state in
            state.lastRequest = request
            return state.answer
        }

        guard
            let url = request.url,
            let http = HTTPURLResponse(
                url: url,
                statusCode: answer.status,
                httpVersion: "HTTP/1.1",
                headerFields: answer.headers
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // MARK: - Nested Types

    private struct Answer {
        let status: Int
        let body: Data
        let headers: [String: String]
    }

    private struct State {
        var answer = Answer(status: 200, body: Data(), headers: [:])
        var lastRequest: URLRequest?
    }

}
