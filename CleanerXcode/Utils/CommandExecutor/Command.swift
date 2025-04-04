//
//  Command.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 04/04/25.
//

import Foundation

struct Command: Identifiable, Equatable {
    
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
    
    static var removeArchives = Command("remove-archives")
    static var removeCaches = Command("remove-caches")
    static var removeDerivedData = Command("remove-derived-data")
    static var clearDeviceSupport = Command("clear-device-support")
    static var clearSimulatorData = Command("clear-simulator-data")
    static var removeOldSimulators = Command("remove-old-simulators")
    static var resetXcodePreferences = Command("reset-xcode-preferences")
    static var calculateFreeUpSpace = Command("calculate-free-up-space")
    
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
