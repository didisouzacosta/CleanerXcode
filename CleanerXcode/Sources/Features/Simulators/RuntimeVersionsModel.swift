//
//  RuntimeVersionsModel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import Observation

/// The versions the "Download runtimes" sheet offers, loaded while it is open (C35, R5). The sheet
/// never waits for them: until they arrive it offers Xcode's version. The SDK versions are published
/// as soon as they arrive, with the last catalog, so Xcode's version shows its number while the
/// catalog loads (Figma 92:8552). Each load takes a generation, so a phase that ends after a newer
/// load started is discarded; a cancelled load (the sheet closed) keeps what it published until then,
/// the SDK phase included, and never leaves the sheet loading.
@Observable
final class RuntimeVersionsModel {

    // MARK: - Public Properties

    /// Read by the composition tests.
    let source: any RuntimeVersionProviding

    /// `nil` until the first load ends; kept while loading again.
    private(set) var snapshot: RuntimeVersionsSnapshot?
    private(set) var isLoading = false

    // MARK: - Private Properties

    @ObservationIgnored private var generation = 0

    // MARK: - Initializers

    init(source: any RuntimeVersionProviding) {
        self.source = source
    }

    // MARK: - Public Methods

    /// When the sheet is asked for, before its first frame: the sheet always loads when it opens, so
    /// it reads as loading at once, never as "unavailable" from a load that was cancelled or failed
    /// before (B4). It does not suspend nor take a generation; the sheet's `load()` follows and ends
    /// the loading. If the sheet closes before its load starts, nothing shows this state, and the
    /// next opening loads again.
    func beginLoading() {
        isLoading = true
    }

    /// Loads again even while a load runs, as "Try again" does; the newest one wins.
    func load() async {
        generation += 1

        let current = generation

        isLoading = true

        do {
            async let catalog = source.catalog()

            let sdkVersions = try await source.sdkVersions()

            if current == generation {
                snapshot = RuntimeVersionsSnapshot(sdkVersions: sdkVersions, catalog: snapshot?.catalog)
            }

            let entries = try await catalog

            if current == generation {
                snapshot = RuntimeVersionsSnapshot(sdkVersions: sdkVersions, catalog: entries)
            }
        } catch {
            // Only cancellation throws: the last versions stay.
        }

        if current == generation {
            isLoading = false
        }
    }

}
