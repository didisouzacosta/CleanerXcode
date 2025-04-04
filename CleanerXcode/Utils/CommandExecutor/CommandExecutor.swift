//
//  CommandExecutor.swift
//  CleanXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

protocol CommandExecutor {
    
    var isCancelled: Bool { get }
    
    func runWatingResult(_ command: Command, timeout: TimeInterval) async throws -> String?
    func cancel()
    
}

extension CommandExecutor {
    
    func run(_ command: Command, timeout: TimeInterval = 10) async throws {
        if let result = try await runWatingResult(command, timeout: timeout), result.lowercased() != "done" {
            throw "Failed command: \(command.id). Error: The response not is \"done\"."
        }
    }
    
    func run<T: Decodable>(
        _ command: Command,
        timeout: TimeInterval = 10,
        decoder: JSONDecoder = .init()
    ) async throws -> T {
        guard let data = try await runWatingResult(command, timeout: timeout)?.data(using: .utf8) else {
            throw "Failed command: \(command.id). Error: The response is empty."
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
}
