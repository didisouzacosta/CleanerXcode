//
//  CommandExecutorStub.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 04/04/25.
//

@testable import CleanerXcode

final class CommandExecutorStub: CommandExecutor {
    
    var result: String?
    var isCancelled = false
    
    func runWatingResult(_ command: Command) async throws -> String? {
        result
    }
    
    func cancel() {
        isCancelled = true
    }
    
}
