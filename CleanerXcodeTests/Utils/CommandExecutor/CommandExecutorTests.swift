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
    
    @Test(arguments: ["done", "Done"])
    func shouldResponseSuccessfullyWhenTheShellResponseIsDone(_ text: String) async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success(text)
        
        try await stubbedCommand.run(.fake)
    }
    
    @Test(arguments: ["doneeee", "true", "yes"])
    func shouldThrowErrorWhenResponseIsDifferentOfDone(_ text: String) async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success(text)
        
        await #expect(throws: Error.self) {
            try await stubbedCommand.run(.fake)
        }
    }
    
    @Test
    func shouldThrowErrorWhenCommandBrokes() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .failure("Error executing script")
        
        await #expect(throws: Error.self) {
            try await stubbedCommand.run(.fake)
        }
        
        await #expect(throws: Error.self) {
            try await stubbedCommand.runWatingResult(.fake)
        }
    }
    
    @Test
    func shouldResponseSuccessfullyWhenTheShellResponseIsAnything() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success("Orlando")
        
        let result = try await stubbedCommand.runWatingResult(.fake)
        
        #expect(result == "Orlando")
    }
    
    @Test
    func shouldResponseSuccessDecodableObject() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success("{\"name\": \"Orlando\"}")
        
        let person: Person = try await stubbedCommand.run(.fake)
        
        #expect(person.name == "Orlando")
    }
    
    @Test
    func shouldThrowErrorOnFailDecodable() async throws {
        let stubbedCommand = StubbedCommandExecutor()
        stubbedCommand.result = .success("{\"age\": 36}")
        
        await #expect(throws: Error.self) {
            _ = try await stubbedCommand.run(.fake)
        }
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
    
    func runWatingResult(_ command: Command) async throws -> String? {
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
