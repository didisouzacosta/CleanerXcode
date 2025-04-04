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

    // MARK: - Public Methods
    
    @Test
    func ensureCalculareFreeUpSpaceCommand() async throws {
        #expect(assert(.calculateFreeUpSpace, script: "calculate-free-up-space"))
    }
    
    @Test
    func ensureClearDeviceSupportCommand() async throws {
        #expect(assert(.clearDeviceSupport, script: "clear-device-support"))
    }
    
    @Test
    func ensureClearSimulatorDataCommand() async throws {
        #expect(assert(.clearSimulatorData, script: "clear-simulator-data"))
    }
    
    @Test
    func ensureRemoveArchivesCommand() async throws {
        #expect(assert(.removeArchives, script: "remove-archives"))
    }
    
    @Test
    func ensureRemoveCachesCommand() async throws {
        #expect(assert(.removeCaches, script: "remove-caches"))
    }
    
    @Test
    func ensureRemoveDerivedDataCommand() async throws {
        #expect(assert(.removeDerivedData, script: "remove-derived-data"))
    }
    
    @Test
    func ensureRemoveOldSimulatorsCommand() async throws {
        #expect(assert(.removeOldSimulators, script: "remove-old-simulators"))
    }
    
    @Test
    func ensureResetXcodePreferencesCommand() async throws {
        #expect(assert(.resetXcodePreferences, script: "reset-xcode-preferences"))
    }
    
    // MARK: - Private Methods
    
    private func assert(
        _ command: Command,
        script: String,
        bundle: Bundle = .main
    ) -> Bool {
        [
            command.id == script,
            command.script == script,
            command.path?.contains(script) == true,
            command.bundle == bundle
        ].allSatisfy { $0 }
    }

}
