//
//  RemoteVersionCheckerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Synchronization
import Testing
@testable import CleanerXcode

/// Answers through a stub `URLProtocol` registered on an ephemeral session: nothing reaches the
/// network. Serialized because the stub's response is shared.
@Suite(.serialized)
struct RemoteVersionCheckerTests {

    // MARK: - Private Properties

    /// A host that never resolves; the stub answers before any lookup.
    private let fileURL = URL(string: "https://updates.invalid/version.json")

    // MARK: - Public Methods

    @Test
    func readsTheVersionFile() async throws {
        VersionFileStub.set(
            status: 200,
            body: #"{"version":"1.0.1","build":"116","downloadURL":"https://example.invalid/app.dmg"}"#
        )

        let version = try await checker().latestVersion()

        #expect(version.version == "1.0.1")
        #expect(version.build == "116")
        #expect(version.downloadURL.absoluteString == "https://example.invalid/app.dmg")
        #expect(VersionFileStub.lastTimeout == 10)
    }

    @Test
    func aServerErrorOrAnUnreadableFileFails() async {
        VersionFileStub.set(status: 500, body: "")

        await #expect(throws: RemoteVersionChecker.CheckError.badResponse) {
            try await checker().latestVersion()
        }

        VersionFileStub.set(status: 200, body: "{ not json")

        await #expect(throws: (any Error).self) {
            try await checker().latestVersion()
        }
    }

    @Test
    func withoutAURLThereIsNothingToCheck() async {
        await #expect(throws: RemoteVersionChecker.CheckError.notConfigured) {
            try await RemoteVersionChecker(url: nil).latestVersion()
        }
    }

    // MARK: - Private Methods

    private func checker() -> RemoteVersionChecker {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VersionFileStub.self]

        return RemoteVersionChecker(url: fileURL, session: URLSession(configuration: configuration))
    }

}

nonisolated private final class VersionFileStub: URLProtocol {

    // MARK: - Public Properties

    static var lastTimeout: TimeInterval {
        state.withLock { $0.lastTimeout }
    }

    // MARK: - Private Properties

    private static let state = Mutex(State())

    // MARK: - Public Methods

    static func set(status: Int, body: String) {
        state.withLock { $0.response = (status, body) }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = Self.state.withLock { state in
            state.lastTimeout = request.timeoutInterval
            return state.response
        }

        guard
            let url = request.url,
            let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // MARK: - Nested Types

    private struct State {
        var response: (status: Int, body: String) = (200, "")
        var lastTimeout: TimeInterval = 0
    }

}
