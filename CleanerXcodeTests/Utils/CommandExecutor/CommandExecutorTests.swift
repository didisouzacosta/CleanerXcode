//
//  CommandExecutorTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct CommandExecutorTests {

    private let commandExecutor = StubbedCommandExecutor()
    
    func shouldResponseSuccessfullyWhenTheShellResponseIsDone(_ text: String) async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success(text)
        
        try await stubbedCommand.run(.fake)
    }
    
    @Test
    func shouldThrowErrorWhenCommandBrokes() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .failure("Error executing script")
        
        await #expect(throws: Error.self) {
            try await stubbedCommand.run(.fake)
        }
        
        await #expect(throws: Error.self) {
            try await stubbedCommand.run(.fake)
        }
    }
    
    @Test
    func shouldResponseSuccessfullyWhenTheShellResponseIsAnything() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success("Orlando")
        
        let result = try await stubbedCommand.run(.fake)
        
        #expect(result == "Orlando")
    }
    
    @Test
    func shouldResponseSuccessDecodableObject() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success("{\"name\": \"Orlando\"}")
        
        let person: Person = try await stubbedCommand.runDecoder(.fake)
        
        #expect(person.name == "Orlando")
    }

}

fileprivate final class StubbedCommandExecutor: CommandExecutor {
    
    enum Result {
        case idle
        case success(String)
        case failure(Error)
    }
    
    var result: Result = .idle
    
    var isCancelled: Bool {
        false
    }
    
    func cancel() {}
    
    @discardableResult
    func run(_ command: Command) async throws -> String? {
        switch result {
        case .failure(let error):
            throw error
        case .success(let success):
            return success
        case .idle:
            return nil
        }
    }
    
}

fileprivate extension Command {
    
    static let fake = Command("fake-command")
    
}
