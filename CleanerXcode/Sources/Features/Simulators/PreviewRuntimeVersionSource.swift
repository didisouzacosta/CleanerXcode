//
//  PreviewRuntimeVersionSource.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

#if DEBUG
    /// The versions of the "Download runtimes" sheet for the previews (C35), close to the Figma frames:
    /// Xcode 27.2 and real catalog sizes. It never runs `xcodebuild` nor reads Apple's catalog.
    nonisolated struct PreviewRuntimeVersionSource: RuntimeVersionProviding {

        // MARK: - Public Properties

        /// Xcode 27.2's SDKs and the final runtimes of Apple's catalog on Apple silicon (2026-11-09).
        static let loaded = RuntimeVersionsSnapshot(
            sdkVersions: sdkVersions,
            catalog: [
                entry(.iOS, "27.2", "24B8117", 8_321_588_736),
                entry(.iOS, "27.1", "24A94425", 7_851_823_104),
                entry(.iOS, "26.5", "23F77", 8_522_901_969),
                entry(.iOS, "26.1", "23B86", 8_321_575_375),
                entry(.iOS, "26.0", "23A343", 7_986_028_446),
                entry(.watchOS, "26.5", "23T570", 3_959_483_106),
                entry(.tvOS, "27.2", "24K150", 3_758_154_240),
                entry(.visionOS, "26.4.1", "23O249a", 7_314_935_697),
            ].compactMap(\.self)
        )

        /// The SDKs, without the catalog: no network nor cache (R6).
        static let unavailable = RuntimeVersionsSnapshot(sdkVersions: sdkVersions, catalog: nil)

        // MARK: - Private Properties

        private static let sdkVersions: [RuntimePlatform: RuntimeBuildVersion] = RuntimeBuildVersion("27.2")
            .map { version in
                Dictionary(uniqueKeysWithValues: RuntimePlatform.allCases.map { ($0, version) })
            } ?? [:]

        private let behavior: Behavior

        // MARK: - Initializers

        init(_ behavior: Behavior) {
            self.behavior = behavior
        }

        // MARK: - Private Static Methods

        private static func entry(
            _ platform: RuntimePlatform,
            _ version: String,
            _ build: String,
            _ size: Int64
        ) -> RuntimeCatalogEntry? {
            RuntimeBuildVersion(version).map {
                RuntimeCatalogEntry(platform: platform, version: $0, build: build, sizeBytes: size)
            }
        }

        // MARK: - Public Methods

        func sdkVersions() -> [RuntimePlatform: RuntimeBuildVersion] {
            Self.sdkVersions
        }

        func catalog() async throws -> [RuntimeCatalogEntry]? {
            switch behavior {
            case .loaded:
                return Self.loaded.catalog

            case .unavailable:
                return nil

            case .neverFinishes:
                try await Task.sleep(for: .seconds(3_600))
                return Self.loaded.catalog
            }
        }

        // MARK: - Nested Types

        enum Behavior: Sendable {
            case loaded
            case unavailable
            /// The SDK versions at once, and the catalog loading until the sheet closes (F3).
            case neverFinishes
        }

    }
#endif
