//
//  Shell.swift
//  CleanXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

final class Shell {
    
    @discardableResult
    func execute(_ command: Command) async throws -> String? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) -> Void in
            guard let scriptPath = command.scriptPath else {
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

extension Shell {
    
    enum Command: String, CaseIterable, Identifiable {
        case removeArchives = "remove-archives"
        case removeCaches = "remove-caches"
        case removeDerivedData = "remove-derived-data"
        case clearDeviceSupport = "clear-device-support"
        case clearSimulatorData = "clear-simulator-data"
        case removeOldSimulators = "remove-old-simulators"
        case resetXcodePreferences = "reset-xcode-preferences"
        case calculateFreeUpSpace = "calculate-free-up-space"
        
        var id: String {
            rawValue
        }
        
        var scriptPath: String? {
            Bundle.main.path(forResource: rawValue, ofType: "sh")
        }
    }
    
}
