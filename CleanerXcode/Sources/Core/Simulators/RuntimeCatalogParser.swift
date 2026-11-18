//
//  RuntimeCatalogParser.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation

/// Reads Apple's catalog of downloadable runtimes into the versions the app offers (C35, R2). Only
/// final cryptex runtimes downloaded as mobile assets, built for this Mac's architecture and without
/// host requirements, are kept: the ones `xcodebuild -downloadPlatform -buildVersion` downloads
/// without a sign-in. The filter is a heuristic over an undocumented format (P2); a version Xcode
/// still refuses fails legibly when downloaded (R9).
nonisolated enum RuntimeCatalogParser {

    // MARK: - Public Properties

    /// When the catalog does not say, as the real one does (86 400 s).
    static let defaultRefreshInterval: Duration = .seconds(86_400)

    /// The architecture names the catalog uses.
    static var hostArchitecture: String {
        #if arch(arm64)
            "arm64"
        #else
            "x86_64"
        #endif
    }

    // MARK: - Private Properties

    private static let cryptexContentType = "cryptexDiskImage"
    private static let mobileAssetMethod = "mobileAsset"
    private static let prereleaseMarkers = ["beta", "release candidate"]

    // MARK: - Public Methods

    /// Binary and XML property lists. Each platform and version appears once: of its builds, the last
    /// one in the catalog's order; of that build's variants, the one built only for `hostArchitecture`,
    /// otherwise the first that includes it. Entries come by platform, newest version first.
    static func catalog(from data: Data, hostArchitecture: String) throws(RuntimeCatalogError) -> RuntimeCatalog {
        let index: RuntimeCatalogDTO.Index

        do {
            index = try PropertyListDecoder().decode(RuntimeCatalogDTO.Index.self, from: data)
        } catch {
            throw .malformed
        }

        let candidates = index.downloadables.compactMap(\.value).compactMap {
            candidate(from: $0, hostArchitecture: hostArchitecture)
        }

        return RuntimeCatalog(
            entries: chosen(from: candidates, hostArchitecture: hostArchitecture),
            refreshInterval: refreshInterval(from: index.refreshInterval)
        )
    }

    // MARK: - Private Methods

    /// A final runtime this Mac can download, or `nil`.
    private static func candidate(
        from downloadable: RuntimeCatalogDTO.Downloadable,
        hostArchitecture: String
    ) -> Candidate? {
        guard
            let platform = downloadable.platform.flatMap(RuntimePlatform.init(catalogPlatformIdentifier:)),
            downloadable.contentType == cryptexContentType,
            downloadable.downloadMethod == mobileAssetMethod,
            !downloadable.hasHostRequirements,
            let name = downloadable.name,
            !isPrerelease(name),
            let architectures = downloadable.architectures,
            architectures.contains(hostArchitecture),
            let version = downloadable.simulatorVersion?.version.flatMap(RuntimeBuildVersion.init),
            let build = downloadable.simulatorVersion?.buildUpdate,
            !build.isEmpty,
            let sizeBytes = downloadable.fileSize,
            sizeBytes > 0
        else { return nil }

        return Candidate(
            entry: RuntimeCatalogEntry(platform: platform, version: version, build: build, sizeBytes: sizeBytes),
            architectures: architectures
        )
    }

    private static func isPrerelease(_ name: String) -> Bool {
        let lowercased = name.lowercased()

        return prereleaseMarkers.contains { lowercased.contains($0) }
    }

    /// One entry per platform and numeric version.
    private static func chosen(from candidates: [Candidate], hostArchitecture: String) -> [RuntimeCatalogEntry] {
        var groups: [VersionKey: [Candidate]] = [:]

        for candidate in candidates {
            groups[VersionKey(candidate.entry), default: []].append(candidate)
        }

        let entries = groups.values.compactMap { group -> RuntimeCatalogEntry? in
            guard let lastBuild = group.last?.entry.build else { return nil }

            let variants = group.filter { $0.entry.build == lastBuild }
            let exact = variants.first { $0.architectures == [hostArchitecture] }

            return (exact ?? variants.first)?.entry
        }

        return entries.sorted(by: isOrderedBefore)
    }

    private static func isOrderedBefore(_ lhs: RuntimeCatalogEntry, _ rhs: RuntimeCatalogEntry) -> Bool {
        let platforms = RuntimePlatform.allCases

        guard lhs.platform == rhs.platform else {
            return (platforms.firstIndex(of: lhs.platform) ?? 0) < (platforms.firstIndex(of: rhs.platform) ?? 0)
        }

        return RuntimeBuildVersion.compareNumerically(lhs.version, rhs.version) == .orderedDescending
    }

    /// Missing, not a number or not positive: one day.
    private static func refreshInterval(from seconds: Double?) -> Duration {
        guard let seconds, seconds.isFinite, seconds > 0 else { return defaultRefreshInterval }

        return .seconds(seconds)
    }

    // MARK: - Nested Types

    private struct Candidate {
        let entry: RuntimeCatalogEntry
        let architectures: [String]
    }

    /// The platform and the version without trailing zeros, so "26.0" and "26" are one version.
    private struct VersionKey: Hashable {

        // MARK: - Public Properties

        let platform: RuntimePlatform
        let components: [Int]

        // MARK: - Initializers

        init(_ entry: RuntimeCatalogEntry) {
            var components = entry.version.numericComponents

            while components.count > 1, components.last == 0 {
                components.removeLast()
            }

            platform = entry.platform
            self.components = components
        }

    }

}
