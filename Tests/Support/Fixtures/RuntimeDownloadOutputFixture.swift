//
//  RuntimeDownloadOutputFixture.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation
import Testing

/// The standard output of a real `xcrun xcodebuild -downloadPlatform tvOS -exportPath <tmp>` (Xcode
/// 27.2, 2026-11-01), cancelled with `SIGTERM` after about 45 s (C34). The original capture was lost;
/// this rebuild keeps the first 16 and the last 13 of its 53 chunks byte for byte, with the `\r`
/// separators, the padding spaces and the "Download was cancelled." left without a newline at the
/// end, and leaves out the middle 24 chunks (0,2% to 0,7%), which
/// repeat the same format. It holds no path nor user name, only the runtime's name and numbers.
nonisolated enum RuntimeDownloadOutputFixture {

    // MARK: - Public Properties

    static let byteCount = 2_049
    static let carriageReturnCount = 26
    static let newlineCount = 3

    // MARK: - Public Methods

    static func tvOSSample() throws -> Data {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: "xcodebuild-download-platform-tvos", withExtension: "txt")
        )

        return try Data(contentsOf: url)
    }

    // MARK: - Nested Types

    private final class BundleToken {}

}
