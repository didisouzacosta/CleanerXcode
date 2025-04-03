//
//  CommandTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct CommandTests {

    @Test func ensureCalculareFreeUpSpaceCommand() async throws {
        let command = Command.calculateFreeUpSpace
        
        #expect(command.id == "calculate-free-up-space")
        #expect(command.script == "calculate-free-up-space")
        #expect(command.path?.contains("calculate-free-up-space.sh") == true)
        #expect(command.bundle == .main)
    }
    
    @Test func ensureClearDeviceSupportCommand() async throws {
        let command = Command.clearDeviceSupport
        
        #expect(command.id == "clear-device-support")
        #expect(command.script == "clear-device-support")
        #expect(command.path?.contains("clear-device-support.sh") == true)
        #expect(command.bundle == .main)
    }
    
    @Test func ensureClearSimulatorDataCommand() async throws {
        let command = Command.clearSimulatorData
        
        #expect(command.id == "clear-simulator-data")
        #expect(command.script == "clear-simulator-data")
        #expect(command.path?.contains("clear-simulator-data.sh") == true)
        #expect(command.bundle == .main)
    }
    
    @Test func ensureRemoveArchivesCommand() async throws {
        let command = Command.removeArchives
        
        #expect(command.id == "remove-archives")
        #expect(command.script == "remove-archives")
        #expect(command.path?.contains("remove-archives.sh") == true)
        #expect(command.bundle == .main)
    }
    
    @Test func ensureRemoveCachesCommand() async throws {
        let command = Command.removeCaches
        
        #expect(command.id == "remove-caches")
        #expect(command.script == "remove-caches")
        #expect(command.path?.contains("remove-caches.sh") == true)
        #expect(command.bundle == .main)
    }
    
    @Test func ensureRemoveDerivedDataCommand() async throws {
        let command = Command.removeDerivedData
        
        #expect(command.id == "remove-derived-data")
        #expect(command.script == "remove-derived-data")
        #expect(command.path?.contains("remove-derived-data.sh") == true)
        #expect(command.bundle == .main)
    }
    
    @Test func ensureRemoveOldSimulatorsCommand() async throws {
        let command = Command.removeOldSimulators
        
        #expect(command.id == "remove-old-simulators")
        #expect(command.script == "remove-old-simulators")
        #expect(command.path?.contains("remove-old-simulators.sh") == true)
        #expect(command.bundle == .main)
    }
    
    @Test func ensureResetXcodePreferencesCommand() async throws {
        let command = Command.resetXcodePreferences
        
        #expect(command.id == "reset-xcode-preferences")
        #expect(command.script == "reset-xcode-preferences")
        #expect(command.path?.contains("reset-xcode-preferences.sh") == true)
        #expect(command.bundle == .main)
    }

}
