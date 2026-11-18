//
//  RuntimeCatalogCache.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// The filtered catalog and when it was read (C35, R7).
nonisolated struct CachedRuntimeCatalog: Sendable, Hashable {
    let catalog: RuntimeCatalog
    let fetchedAt: Date
}

/// Keeps the last catalog read, so the sheet does not read Apple's catalog more than its refresh
/// interval asks, and still offers the earlier versions offline (R7).
nonisolated protocol RuntimeCatalogStoring: Sendable {
    /// `nil` when there is none, or it cannot be read.
    func load() async -> CachedRuntimeCatalog?
    /// A failed write is ignored: the cache only saves time.
    func save(_ cached: CachedRuntimeCatalog) async
}

/// A small JSON file in the app's caches folder (`~/Library/Caches/<bundle id>`), with a format
/// version. Each entry is checked again when read, so a damaged or edited file can only lose
/// entries, never turn into an argument of `xcodebuild` (R7). The file is replaced atomically.
nonisolated struct FileRuntimeCatalogCache: RuntimeCatalogStoring {

    // MARK: - Public Properties

    static let fileName = "simulator-runtime-catalog.json"
    static let formatVersion = 1

    let directory: URL

    var fileURL: URL {
        directory.appending(path: Self.fileName, directoryHint: .notDirectory)
    }

    // MARK: - Initializers

    init(directory: URL) {
        self.directory = directory
    }

    // MARK: - Private Static Methods

    private static func entry(from file: FileEntry) -> RuntimeCatalogEntry? {
        guard
            let platform = RuntimePlatform(rawValue: file.platform),
            let version = RuntimeBuildVersion(file.version),
            file.sizeBytes > 0
        else { return nil }

        return RuntimeCatalogEntry(platform: platform, version: version, build: file.build, sizeBytes: file.sizeBytes)
    }

    // MARK: - Public Methods

    @concurrent
    func load() async -> CachedRuntimeCatalog? {
        guard
            let data = try? Data(contentsOf: fileURL),
            let file = try? JSONDecoder().decode(CacheFile.self, from: data),
            file.formatVersion == Self.formatVersion
        else { return nil }

        return CachedRuntimeCatalog(
            catalog: RuntimeCatalog(
                entries: file.entries.compactMap(\.value).compactMap(Self.entry(from:)),
                refreshInterval: .seconds(file.refreshIntervalSeconds)
            ),
            fetchedAt: Date(timeIntervalSince1970: file.fetchedAt)
        )
    }

    @concurrent
    func save(_ cached: CachedRuntimeCatalog) async {
        let file = CacheFile(
            formatVersion: Self.formatVersion,
            fetchedAt: cached.fetchedAt.timeIntervalSince1970,
            refreshIntervalSeconds: cached.catalog.refreshInterval.components.seconds,
            entries: cached.catalog.entries.map { entry in
                LossyElement(value: FileEntry(
                    platform: entry.platform.rawValue,
                    version: entry.version.rawValue,
                    build: entry.build,
                    sizeBytes: entry.sizeBytes
                ))
            }
        )

        do {
            let data = try JSONEncoder().encode(file)

            try FileManager().createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Without the cache the catalog is only read again next time.
        }
    }

    // MARK: - Nested Types

    /// Strings and numbers only.
    private struct CacheFile: Codable {
        let formatVersion: Int
        let fetchedAt: Double
        let refreshIntervalSeconds: Int64
        let entries: [LossyElement<FileEntry>]
    }

    private struct FileEntry: Codable {
        let platform: String
        let version: String
        let build: String
        let sizeBytes: Int64
    }

}
