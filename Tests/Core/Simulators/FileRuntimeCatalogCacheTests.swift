//
//  FileRuntimeCatalogCacheTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The filtered catalog kept on disk between launches (C35, R7), in a folder of the test's own.
struct FileRuntimeCatalogCacheTests {

    // MARK: - Private Properties

    private let fetchedAt = Date(timeIntervalSince1970: 1_794_000_000)

    // MARK: - Public Methods

    @Test
    func savesAndLoadsTheCatalogInAFolderItCreates() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let directory = fixture.url.appending(path: "Caches/com.example.app", directoryHint: .isDirectory)
        let cache = FileRuntimeCatalogCache(directory: directory)
        let cached = try CachedRuntimeCatalog(catalog: catalog(), fetchedAt: fetchedAt)

        #expect(await cache.load() == nil)

        await cache.save(cached)

        #expect(await cache.load() == cached)
        #expect(cache.fileURL == directory.appending(path: "simulator-runtime-catalog.json"))
        #expect(FileManager.default.fileExists(atPath: cache.fileURL.path(percentEncoded: false)))
    }

    /// A small JSON file of strings and numbers, with its format version.
    @Test
    func writesAVersionedJSONFile() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let cache = FileRuntimeCatalogCache(directory: fixture.url)

        try await cache.save(CachedRuntimeCatalog(catalog: catalog(), fetchedAt: fetchedAt))

        let data = try Data(contentsOf: cache.fileURL)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try #require(object["entries"] as? [[String: Any]])

        #expect(object["formatVersion"] as? Int == 1)
        #expect(object["refreshIntervalSeconds"] as? Int == 7_200)
        #expect(object["fetchedAt"] as? Double == fetchedAt.timeIntervalSince1970)
        #expect(entries.first?["platform"] as? String == "iOS")
        #expect(entries.first?["version"] as? String == "26.5")
        #expect(entries.first?["build"] as? String == "23F77")
        #expect(entries.first?["sizeBytes"] as? Int == 8_522_901_969)
        #expect(data.count < 2_000)
    }

    /// Each entry is checked again when read: a bad one is left out, the others stay.
    @Test
    func revalidatesEachEntryWhenReading() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let cache = FileRuntimeCatalogCache(directory: fixture.url)

        try write(
            """
            {"formatVersion": 1, "fetchedAt": 1794000000, "refreshIntervalSeconds": 86400, "entries": [
              {"platform": "iOS", "version": "26.5", "build": "23F77", "sizeBytes": 8522901969},
              {"platform": "macOS", "version": "26.5", "build": "25F1", "sizeBytes": 1},
              {"platform": "iOS", "version": "-exportPath", "build": "23F1", "sizeBytes": 1},
              {"platform": "iOS", "version": "26.4", "build": "23E244", "sizeBytes": 0},
              {"platform": "iOS", "version": 26.3, "build": "23D1", "sizeBytes": 1},
              {"platform": "tvOS", "version": "27.2", "build": "24K150", "sizeBytes": 3758154240}
            ]}
            """,
            to: cache
        )

        let loaded = try #require(await cache.load())

        #expect(loaded.fetchedAt == fetchedAt)
        #expect(loaded.catalog.refreshInterval == .seconds(86_400))
        #expect(loaded.catalog.entries.map(\.platform) == [.iOS, .tvOS])
        #expect(loaded.catalog.entries.map(\.version.rawValue) == ["26.5", "27.2"])
    }

    @Test(arguments: [
        #"{"formatVersion": 2, "fetchedAt": 1794000000, "refreshIntervalSeconds": 86400, "entries": []}"#,
        #"{"fetchedAt": 1794000000, "refreshIntervalSeconds": 86400, "entries": []}"#,
        #"{"formatVersion": 1, "entries": []}"#,
        "not json",
        "",
    ])
    func anUnknownFormatOrAnUnreadableFileIsNoCache(contents: String) async throws {
        let fixture = try TemporaryDirectoryFixture()
        let cache = FileRuntimeCatalogCache(directory: fixture.url)

        try write(contents, to: cache)

        #expect(await cache.load() == nil)
    }

    /// The cache only saves time: a folder it cannot write is ignored.
    @Test
    func aFailedWriteIsIgnored() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let blocker = try fixture.makeFile("blocker")
        let cache = FileRuntimeCatalogCache(directory: blocker.appending(path: "inside", directoryHint: .isDirectory))

        try await cache.save(CachedRuntimeCatalog(catalog: catalog(), fetchedAt: fetchedAt))

        #expect(await cache.load() == nil)
    }

    // MARK: - Private Methods

    private func catalog() throws -> RuntimeCatalog {
        let version = try #require(RuntimeBuildVersion("26.5"))

        return RuntimeCatalog(
            entries: [RuntimeCatalogEntry(platform: .iOS, version: version, build: "23F77", sizeBytes: 8_522_901_969)],
            refreshInterval: .seconds(7_200)
        )
    }

    private func write(_ contents: String, to cache: FileRuntimeCatalogCache) throws {
        try FileManager.default.createDirectory(at: cache.directory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: cache.fileURL)
    }

}
