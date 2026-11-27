//
//  VersionFileUpdaterTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The update path of a build without Sparkle (C42): `version.json` names the newest version and
/// its download, which opens in the browser.
struct VersionFileUpdaterTests {

    // MARK: - Public Methods

    @Test
    func aNewerVersionIsOffered() async throws {
        let updater = makeUpdater(current: "0.9.0", build: "90", remote: .success(version("0.10.0", "100")))

        let newer = try await updater.newerVersion()

        #expect(newer == "0.10.0")
    }

    @Test
    func theSameOrAnOlderVersionIsNot() async throws {
        let same = makeUpdater(current: "1.0.0", build: "115", remote: .success(version("1.0.0", "115")))
        let older = makeUpdater(current: "1.0.0", build: "115", remote: .success(version("0.7.0", "70")))

        let sameResult = try await same.newerVersion()
        let olderResult = try await older.newerVersion()

        #expect(sameResult == nil)
        #expect(olderResult == nil)
    }

    @Test
    func aNewerBuildOfTheSameVersionIsOffered() async throws {
        let updater = makeUpdater(current: "1.0.0", build: "115", remote: .success(version("1.0.0", "116")))

        let newer = try await updater.newerVersion()

        #expect(newer == "1.0.0")
    }

    @Test
    func anUnreadableRemoteVersionIsIgnored() async throws {
        let updater = makeUpdater(current: "1.0.0", build: "1", remote: .success(version("next", "1")))

        let newer = try await updater.newerVersion()

        #expect(newer == nil)
    }

    @Test
    func checkErrorsReachTheCaller() async {
        let updater = makeUpdater(current: "1.0.0", build: "1", remote: .failure(URLError(.notConnectedToInternet)))

        await #expect(throws: URLError.self) {
            try await updater.newerVersion()
        }
    }

    @Test
    func presentingOpensTheDownloadOfTheNewerVersion() async throws {
        let opener = URLOpenerSpy()
        let updater = makeUpdater(current: "0.9.0", build: "1", remote: .success(version("1.0.0", "2")), opener: opener)

        _ = try await updater.newerVersion()
        updater.presentUpdate()

        #expect(opener.urls == [URL(filePath: "/app.dmg")])
    }

    @Test
    func nothingOpensWithoutANewerVersion() async throws {
        let opener = URLOpenerSpy()
        let updater = makeUpdater(current: "1.0.0", build: "1", remote: .success(version("1.0.0", "1")), opener: opener)

        _ = try await updater.newerVersion()
        updater.presentUpdate()

        #expect(opener.urls.isEmpty)
    }

    @Test
    func userChecksAndAutomaticChecksNeedSparkle() {
        let updater = makeUpdater(current: "1.0.0", build: "1", remote: .success(version("1.0.0", "1")))

        updater.setAutomaticallyChecksForUpdates(true)

        #expect(updater.supportsUserChecks == false)
        #expect(updater.automaticallyChecksForUpdates == false)
    }

    // MARK: - Private Methods

    private func makeUpdater(
        current: String,
        build: String,
        remote: Result<Version, any Error>,
        opener: URLOpenerSpy = URLOpenerSpy()
    ) -> VersionFileUpdater {
        VersionFileUpdater(
            currentVersion: current,
            currentBuild: build,
            checker: VersionCheckerStub(result: remote),
            open: opener.open
        )
    }

    private func version(_ version: String, _ build: String) -> Version {
        Version(version: version, build: build, downloadURL: URL(filePath: "/app.dmg"))
    }

}

private struct VersionCheckerStub: VersionChecking {

    // MARK: - Public Properties

    let result: Result<Version, any Error>

    // MARK: - Public Methods

    func latestVersion() throws -> Version {
        try result.get()
    }

}

private final class URLOpenerSpy {

    // MARK: - Public Properties

    private(set) var urls: [URL] = []

    // MARK: - Public Methods

    func open(_ url: URL) {
        urls.append(url)
    }

}
