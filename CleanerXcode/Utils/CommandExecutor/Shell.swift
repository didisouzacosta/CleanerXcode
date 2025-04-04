//
//  ShellCommand.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/04/25.
//

import Foundation

final class Shell: CommandExecutor {
    
    @discardableResult
    func runWatingResponse(_ command: Command) async throws -> String? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) -> Void in
            guard let scriptPath = command.path else {
                continuation.resume(throwing: "Script not found in bundle")
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                try process.run()

                var outputString: String?

                if let outputData = try outputPipe.fileHandleForReading.readToEnd() {
                    outputString = String(data: outputData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                process.waitUntilExit()
                
                continuation.resume(with: .success(outputString))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
}
