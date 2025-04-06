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
    _ timeout: TimeInterval = 3,
    condition: @escaping () -> Bool,
    whileWaiting: @escaping () -> Void = {}
) throws {
    let startTime = Date()
    
    repeat {
        whileWaiting()
        Thread.sleep(forTimeInterval: 0.1)
    } while !condition() && Date().timeIntervalSince(startTime) < timeout
}
