//
//  TestImprovements.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation
import Testing

func waitUntil(
    _ timeout: TimeInterval = 3,
    condition: () -> Bool,
    whileWaiting: () -> Void = {}
) async throws {
    let startTime = Date()

    repeat {
        whileWaiting()
        try await Task.sleep(for: .milliseconds(100))
    } while !condition() && Date().timeIntervalSince(startTime) < timeout
}
