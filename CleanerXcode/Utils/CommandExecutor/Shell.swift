//
//  ShellCommand.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/04/25.
//

import Foundation
import Timeout

final class Shell: CommandExecutor {
    
    // MARK: - Public Variables
    
    var isCancelled: Bool {
        task?.isCancelled ?? true
    }
    
    // MARK: - Private Variables
    
    private var task: Task<String?, Error>?
    
    // MARK: - Public Methods
    
    func runWatingResult(_ command: Command) async throws -> String? {
        guard let scriptPath = command.path else {
            throw "Failed command: \(command.id). Error: Script not found in bundle."
        }
        
        return try await withThrowingTimeout(seconds: command.timeout) {
            task = Task(priority: .background) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [scriptPath]

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                try Task.checkCancellation()
                try process.run()

                var outputString: String?

                if let outputData = try outputPipe.fileHandleForReading.readToEnd() {
                    outputString = String(data: outputData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                process.waitUntilExit()
                
                return outputString
            }
            
            return try await task?.value
        }
    }
    
    func cancel() {
        task?.cancel()
    }
    
}
