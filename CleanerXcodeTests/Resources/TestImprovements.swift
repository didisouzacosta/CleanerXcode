//
//  TestImprovements.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation
import Testing

@MainActor
func waitUntil(
    _ timeout: TimeInterval = 3,
    condition: @escaping @MainActor () -> Bool,
    whileWaiting: @escaping @MainActor () -> Void = {}
) async throws {
    let startTime = Date()
    
    repeat {
        whileWaiting()
        try await Task.sleep(for: .milliseconds(25))
    } while !condition() && Date().timeIntervalSince(startTime) < timeout
}
