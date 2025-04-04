//
//  CommandExecutor.swift
//  CleanXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

protocol CommandExecutor {
    func runWatingResponse(_ command: Command) async throws -> String?
}

extension CommandExecutor {
    
    func run(_ command: Command) async throws {
        if let result = try await runWatingResponse(command), result.lowercased() != "done" {
            throw "Failed command: \(command.id). Error: The response not is \"done\"."
        }
    }
    
    func run<T: Decodable>(
        _ command: Command,
        decoder: JSONDecoder = .init()
    ) async throws -> T {
        guard let data = try await runWatingResponse(command)?.data(using: .utf8) else {
            throw "Failed command: \(command.id). Error: The response is empty."
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
}
