//
//  Shell.swift
//  CleanXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

final class Shell {
    
    func execute(_ command: Command) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
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
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if let outputString = String(data: outputData, encoding: .utf8) {
                    print("Script Output: \(outputString)")
                }
                
                process.waitUntilExit()
                continuation.resume()
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
        case removeDeviceSupport = "remove-device-support"
        case removeOldSimulators = "remove-old-simulators"
        case removeSimulatorData = "remove-simulator-data"
        case resetXcode = "reset-xcode"
        
        var id: String {
            rawValue
        }
        
        var scriptPath: String? {
            Bundle.main.path(forResource: rawValue, ofType: "sh")
        }
    }
    
}
