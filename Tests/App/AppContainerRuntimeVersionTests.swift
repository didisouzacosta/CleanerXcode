//
//  AppContainerRuntimeVersionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The versions of the "Download runtimes" sheet (C35, AC15): the test host and previews never run
/// `xcodebuild` nor read Apple's catalog; the app reads both, with its cache in its caches folder.
struct AppContainerRuntimeVersionTests {

    // MARK: - Private Properties

    private let configuration = AppConfiguration(bundleIdentifier: "com.example.cleaner")

    // MARK: - Public Methods

    @Test(arguments: [
        AppEnvironment(isRunningTests: true, isDebug: true),
        AppEnvironment(isRunningTests: false, isRunningPreviews: true, isDebug: true),
    ])
    func theTestHostAndPreviewsOfferOnlyXcodesVersion(environment: AppEnvironment) async {
        let services = AppContainer.makeServices(environment: environment, configuration: configuration)
        let viewModel = AppContainer.makeSimulatorsViewModel(environment: environment, services: services)

        await viewModel.runtimeVersions.load()

        #expect(viewModel.runtimeVersions.source is InertRuntimeVersionSource)
        #expect(viewModel.runtimeVersions.snapshot == RuntimeVersionsSnapshot(sdkVersions: [:], catalog: nil))
    }

    /// Only the type is checked: a test must never read the catalog nor run `xcodebuild`.
    @Test
    func theAppReadsTheSDKsAndTheCatalog() {
        let environment = AppEnvironment(isRunningTests: false, isDebug: true)
        let services = AppContainer.makeServices(environment: environment, configuration: configuration)

        let viewModel = AppContainer.makeSimulatorsViewModel(environment: environment, services: services)

        #expect(viewModel.runtimeVersions.source is RuntimeVersionSource)
    }

    @Test
    func theCatalogCacheLivesInTheAppsCachesFolder() throws {
        let caches = try #require(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)

        #expect(
            AppContainer.runtimeCatalogCacheDirectory(bundleIdentifier: "com.example.cleaner")
                == caches.appending(path: "com.example.cleaner", directoryHint: .isDirectory)
        )
        #expect(
            AppContainer.runtimeCatalogCacheDirectory(bundleIdentifier: nil)
                == caches.appending(path: "com.didisouzacosta.CleanerXcode", directoryHint: .isDirectory)
        )
    }

}
