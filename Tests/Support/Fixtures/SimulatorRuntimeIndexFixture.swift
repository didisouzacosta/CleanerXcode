//
//  SimulatorRuntimeIndexFixture.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing

/// A reduced copy of Apple's catalog of downloadable simulator runtimes (`index2.dvtdownloadableindex`,
/// read on 2026-11-09), as an XML property list (C35). Its 24 real entries keep their values; two more
/// are made up from real ones: iOS 26.2 with `fileSize` as text, and a macOS entry. It holds no path
/// nor user data, only public catalog values.
nonisolated enum SimulatorRuntimeIndexFixture {

    // MARK: - Public Methods

    static func data() throws -> Data {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: "simulator-runtime-index-reduced", withExtension: "plist")
        )

        return try Data(contentsOf: url)
    }

    // MARK: - Nested Types

    private final class BundleToken {}

}
