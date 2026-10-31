//
//  TemporaryDirectoryFixture.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// A unique folder created by the test itself and removed when the fixture goes away, so file
/// system tests never touch real user data.
final class TemporaryDirectoryFixture {

    // MARK: - Public Properties

    let url: URL

    // MARK: - Initializers

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "CleanerXcodeTests-\(UUID().uuidString)", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.resolvingSymlinksInPath()
    }

    // MARK: - Public Methods

    @discardableResult
    func makeDirectory(_ path: String) throws -> URL {
        let directory = url.appending(path: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    func makeFile(_ path: String, bytes: Int = 1) throws -> URL {
        let file = url.appending(path: path, directoryHint: .notDirectory)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0, count: bytes).write(to: file)
        return file
    }

    // MARK: - Deinitializer

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

}
