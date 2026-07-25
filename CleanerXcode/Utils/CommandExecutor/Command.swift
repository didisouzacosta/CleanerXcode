//
//  Command.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 04/04/25.
//

import Foundation

struct Command: Identifiable, Equatable, Sendable {
    
    // MARK: - Public Variables
    
    let script: String
    let bundle: Bundle
    let timeout: TimeInterval
    
    var id: String {
        script
    }
    
    var path: String? {
        bundle.path(forResource: script, ofType: "sh")
    }
    
    // MARK: - Initializers
    
    init(
        _ script: String,
        timeout: TimeInterval = 10,
        bundle: Bundle = .main
    ) {
        self.script = script
        self.timeout = timeout
        self.bundle = bundle
    }
    
}

extension Command {
    
    static let removeArchives = Command("remove-archives")
    static let removeCaches = Command("remove-caches")
    static let removeDerivedData = Command("remove-derived-data")
    static let clearDeviceSupport = Command("clear-device-support")
    static let clearSimulatorData = Command("clear-simulator-data")
    static let removeOldSimulators = Command("remove-old-simulators")
    static let resetXcodePreferences = Command("reset-xcode-preferences")
    static let calculateFreeUpSpace = Command("calculate-free-up-space")
    
    static var commands: [Command] {
        [
            removeArchives,
            removeCaches,
            removeDerivedData,
            clearDeviceSupport,
            clearSimulatorData,
            removeOldSimulators,
            resetXcodePreferences,
            calculateFreeUpSpace
        ]
    }
    
}
