//
//  ShellTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct ShellTests {

    // MARK: - Private Variables
    
    private let shell = Shell()
    
    // MARK: - Public Methods
    
    @Test
    func ensureSuccessfullyExecution() async throws {
        try await shell.run(.success)
    }
    
    @Test
    func ensureDecoderSuccessfull() async throws {
        let person: Person = try await shell.run(.decoder)
        
        #expect(person.name == "Orlando")
    }
    
    @Test
    func ensureFailureExecution() async throws {
        await #expect(throws: Error.self) {
            try await shell.run(.fail)
        }
    }

}

fileprivate extension Command {
    
    static let success = Command("success-command", bundle: .test)
    static let decoder = Command("decoder-command", bundle: .test)
    static let fail = Command("fail-command", bundle: .test)
    
}
