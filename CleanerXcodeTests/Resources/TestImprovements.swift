//
//  TestImprovements.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation
import Testing

@Sendable
func waitUntil(
    _ condition: @escaping () -> Bool,
    whileWaiting: @escaping () -> Void = {}
) throws {
    repeat {
        whileWaiting()
    } while !condition()
}
