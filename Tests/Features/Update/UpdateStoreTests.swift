//
//  UpdateStoreTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 23/03/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct UpdateStoreTests {

    // MARK: - Public Methods

    @Test func ensureUpdateVersionAfterCheckUpdates() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.0.1",
            build: "1",
            fullVersion: "0.0.1.1"
        ) {
            .init(
                version: "0.0.1",
                build: "1",
                downloadURL: .fake
            )
        }

        let store = UpdateStore(applicationInfoStub)

        #expect(store.hasUpdate.isLoading == false)

        store.checkUpdates()

        try await waitUntil {
            store.version != nil
        } whileWaiting: {
            #expect(store.hasUpdate.isLoading == true)
        }

        #expect(store.hasUpdate.isLoading == false)
        #expect(store.version?.version == "0.0.1")
        #expect(store.version?.build == "1")
    }

    @Test func hasUpdatesShouldNotBeTrueWhenLocalVersionIsGreatherThanTheRemoteVersion() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.1.0",
            build: "100",
            fullVersion: "0.1.0.100"
        ) {
            .init(
                version: "0.0.1",
                build: "1",
                downloadURL: .fake
            )
        }

        let store = UpdateStore(applicationInfoStub)

        store.checkUpdates()

        try await waitUntil {
            store.version != nil
        }

        #expect(store.hasUpdate.value == false)
    }

    @Test func hasUpdatesShouldNotBeTrueWhenLocalVersionIsEqualThanTheRemoteVersion() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.1.0",
            build: "100",
            fullVersion: "0.1.0.100"
        ) {
            .init(
                version: "0.1.0",
                build: "100",
                downloadURL: .fake
            )
        }

        let store = UpdateStore(applicationInfoStub)

        store.checkUpdates()

        try await waitUntil {
            store.version != nil
        }

        #expect(store.hasUpdate.value == false)
    }

    @Test func hasUpdatesShouldBeTrueWhenLocalVersionIsLessThanTheRemoteVersion() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.0.1",
            build: "1",
            fullVersion: "0.0.1.100"
        ) {
            .init(
                version: "0.1.0",
                build: "100",
                downloadURL: .fake
            )
        }

        let store = UpdateStore(applicationInfoStub)

        store.checkUpdates()

        try await waitUntil { store.version != nil && store.hasUpdate.isModified }

        #expect(store.hasUpdate.value == true)
    }

    @Test func hasUpdatesShouldBeFalseOnError() async throws {
        let applicationInfoStub = ApplicationInforStub(
            version: "0.0.1",
            build: "1",
            fullVersion: "0.0.1.100"
        ) {
            throw "Failure on load version"
        }

        let store = UpdateStore(applicationInfoStub)

        #expect(store.hasUpdate.value == false)

        store.checkUpdates()

        try await waitUntil {
            store.hasUpdate.isLoading == false
        } whileWaiting: {
            #expect(store.hasUpdate.isLoading == true)
        }

        #expect(store.hasUpdate.value == false)
    }

}

private struct ApplicationInforStub: ApplicationInfo {

    // MARK: - Nested Types

    typealias Handler = () throws -> Version

    var version: String
    var build: String
    var fullVersion: String
    var remoteVersionHandler: Handler

    init(
        version: String,
        build: String,
        fullVersion: String,
        remoteVersionHandler: @escaping Handler
    ) {
        self.version = version
        self.build = build
        self.fullVersion = fullVersion
        self.remoteVersionHandler = remoteVersionHandler
    }

    func loadLatestVersionFromRemote() throws -> Version {
        try remoteVersionHandler()
    }

}

private extension URL {

    static let fake = Constants.staticURL("https://fake.url.com")

}
