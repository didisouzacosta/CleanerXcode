//
//  CommandExecutor.swift
//  CleanXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

protocol CommandExecutor {
    func runWithResult(_ command: Command) async throws -> String?
}

extension CommandExecutor {
    
    func run(_ command: Command) async throws {
        guard let result = try await runWithResult(command) else {
            throw "Failed command: \(command.id)"
        }
        
        if result.lowercased() != "done" {
            throw "Failed command: \(command.id)"
        }
    }
    
}
