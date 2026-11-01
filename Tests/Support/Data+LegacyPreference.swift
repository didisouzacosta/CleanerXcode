//
//  Data+LegacyPreference.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 01/11/26.
//

import Foundation

extension Data {

    /// How 0.7 saved a switch: `Data` holding JSON for `Bool`.
    nonisolated static func legacyPreference(_ value: Bool) -> Data {
        Data((value ? "true" : "false").utf8)
    }

}
