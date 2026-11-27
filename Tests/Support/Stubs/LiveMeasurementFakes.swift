//
//  LiveMeasurementFakes.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// The folders that "exist" for a test, by path without a trailing slash.
final class ExistingFolders {

    // MARK: - Public Properties

    var paths: Set<String> = []

    // MARK: - Public Methods

    func existingDirectory(_ url: URL) -> String? {
        let path = String(url.path(percentEncoded: false).dropLast())

        return paths.contains(path) ? path : nil
    }

}

/// A condition a test turns on and off.
final class Flag {
    var isOn = false
}
