//
//  ProcessOutput.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// The output of a command that exited with status 0.
nonisolated struct ProcessOutput: Sendable, Hashable {
    let standardOutput: Data
    let standardError: Data
}
