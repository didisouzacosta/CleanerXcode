//
//  ShellCommander.swift
//  CleanXCode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

final class ShellCommander {
    
    func clean() async throws {
        try await execute("clean-xcode")
    }
    
    func execute(_ script: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            guard let scriptPath = Bundle.main.path(forResource: script, ofType: "sh") else {
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
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let outputString = String(data: outputData, encoding: .utf8) {
                    print("Script Output: \(outputString)")
                }
                
                process.waitUntilExit()
                continuation.resume(with: .success(()))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
}
