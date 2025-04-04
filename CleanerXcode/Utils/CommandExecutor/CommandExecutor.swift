//
//  CommandExecutor.swift
//  CleanXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

protocol CommandExecutor {
    
    var isCancelled: Bool { get }
    
    func runWatingResult(_ command: Command) async throws -> String?
    func cancel()
    
}

extension CommandExecutor {
    
    func run(_ command: Command) async throws {
        if let result = try await runWatingResult(command), result.lowercased() != "done" {
            throw "Failed command: \(command.id). Error: The response not is \"done\"."
        }
    }
    
    func run<T: Decodable>(_ command: Command, decoder: JSONDecoder = .init()) async throws -> T {
        let response = try await runWatingResult(command)
        
        guard let data = response?.data(using: .utf8) else {
            throw "Failed command: \(command.id). Error: The response is empty."
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
}
