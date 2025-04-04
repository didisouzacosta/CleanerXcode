//
//  CommandExecutor.swift
//  CleanXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

protocol CommandExecutor {
    
    var isCancelled: Bool { get }
    
    @discardableResult
    func run(_ command: Command) async throws -> String?
    
    func cancel()
    
}

extension CommandExecutor {
    
    func runDecoder<T: Decodable>(_ command: Command, decoder: JSONDecoder = .init()) async throws -> T {
        let response = try await run(command)
        
        guard let data = response?.data(using: .utf8) else {
            throw "Failed command: \(command.id). Error: The response is empty."
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
}
