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
    func ensureDecoderSuccessfullExecution() async throws {
        let person: Person = try await shell.runDecoder(.decoder)
        
        #expect(person.name == "Orlando")
    }
    
    @Test
    func ensureTimeoutError() async throws {
        let error = await #expect(throws: Error.self) {
            try await shell.run(.timeout)
        }
        
        #expect(error?.localizedDescription == "Task timed out before completion. Timeout: 2.0 seconds.")
    }

}

fileprivate extension Command {
    
    static let success = Command("success-command", bundle: .test)
    static let decoder = Command("decoder-command", bundle: .test)
    static let fail = Command("fail-command", bundle: .test)
    static let timeout = Command("timeout-command", timeout: 2, bundle: .test)
    
}
