//
//  DeviceSet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The default simulator set or another one, such as the XCTest or Previews sets.
nonisolated enum DeviceSet: Sendable, Hashable {

    // MARK: - Cases

    case `default`
    case custom(URL)

    // MARK: - Public Properties

    /// Goes right after `simctl`, before the subcommand.
    var arguments: [String] {
        switch self {
        case .default: []
        case let .custom(url): ["--set", url.path(percentEncoded: false)]
        }
    }

}
